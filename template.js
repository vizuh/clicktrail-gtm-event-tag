/*
 * ClickTrail Event Tag v1
 *
 * Builds a canonical ClickTrail payload (schema_version 1.2.0 conventions)
 * and pushes it onto the page dataLayer under the 'clicktrail' event name.
 * The ClickTrail browser adapter (clicktrail-js) or any downstream GTM tag
 * can consume it from there.
 *
 * Permission footprint (deliberately minimal):
 *   - access_globals: push to window.dataLayer; one namespaced key for the
 *     client-side deduplication ring buffer.
 *   - get_url: read the current page URL when "Include page location" is on.
 *   - logging: console output in preview/debug only.
 * No script injection, no pixels, no cookies, no localStorage.
 */

const createQueue = require('createQueue');
const copyFromWindow = require('copyFromWindow');
const setInWindow = require('setInWindow');
const getUrl = require('getUrl');
const makeTableMap = require('makeTableMap');
const log = require('logToConsole');
const JSON = require('JSON');

const SEEN_KEY = 'clicktrail_gtm_seen_events';
const MAX_SEEN = 20;

function toNumber(value) {
  if (value === undefined || value === null || value === '') return undefined;
  const n = Number(value);
  return isNaN(n) ? undefined : n;
}

function normalizeAttribution(input) {
  if (!input) return undefined;
  let attr = input;
  if (typeof attr === 'string') {
    try {
      attr = JSON.parse(attr);
    } catch (e) {
      if (data.debug) log('ClickTrail: attribution value is not valid JSON, ignoring.');
      return undefined;
    }
  }
  if (typeof attr !== 'object') return undefined;
  return attr;
}

/* --- client-side deduplication -------------------------------------- */
if (data.eventId) {
  let seen = copyFromWindow(SEEN_KEY);
  if (!seen || typeof seen.indexOf !== 'function') seen = [];
  if (seen.indexOf(data.eventId) >= 0) {
    if (data.debug) log('ClickTrail: duplicate event suppressed (' + data.eventId + ').');
    return;
  }
  seen.push(data.eventId);
  if (seen.length > MAX_SEEN) seen = seen.slice(seen.length - MAX_SEEN);
  setInWindow(SEEN_KEY, seen, false);
}

/* --- build canonical payload ---------------------------------------- */
const event = { name: data.eventName };
if (data.eventId) event.id = data.eventId;
if (data.objectType && data.objectType !== 'none') {
  event.object_type = data.objectType;
  if (data.objectId) event.object_id = data.objectId;
}
const value = toNumber(data.eventValue);
if (value !== undefined) event.value = value;
if (data.currency) event.currency = data.currency;

const payload = {
  schema_version: '1.2.0',
  source: 'gtm',
  site_id: data.siteId,
  event: event
};

const attribution = normalizeAttribution(data.attributionVariable);
if (attribution) payload.attribution = attribution;

if (data.includePageData) {
  try {
    payload.page = { location: getUrl('URL') };
  } catch (e) {
    /* URL permission unavailable at runtime; skip page context */
  }
}

if (data.customProperties && data.customProperties.length) {
  try {
    payload.properties = makeTableMap(data.customProperties, 'name', 'value');
  } catch (e) {
    if (data.debug) log('ClickTrail: invalid custom property table, ignoring.');
  }
}

/* --- deliver --------------------------------------------------------- */
const dataLayer = createQueue('dataLayer');
dataLayer.push({
  event: 'clicktrail',
  clicktrail_version: '1',
  clicktrail_event: payload
});

if (data.debug) log('ClickTrail event pushed:', payload);

// Signal successful tag completion to GTM.
data.gtmOnSuccess();
