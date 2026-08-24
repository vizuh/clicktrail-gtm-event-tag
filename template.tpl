___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "ct_evt",
  "version": 1,
  "securityGroups": [],
  "displayName": "ClickTrail Event Tag",
  "categories": [
    "ADVERTISING",
    "CONVERSIONS",
    "LEAD_GENERATION"
  ],
  "description": "Send lead, booking, order and contact events to ClickTrail as a canonical, schema-versioned payload. Pushes to the page dataLayer with tightly scoped permissions - no script injection, no pixels, no cookies.",
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___


[
  {
    "type": "TEXT",
    "name": "siteId",
    "displayName": "ClickTrail Site ID",
    "simpleValueType": true,
    "help": "The site or tenant ID configured in ClickTrail (WordPress plugin: ClickTrail > Settings).",
    "valueValidators": [
      { "type": "NON_EMPTY" }
    ]
  },
  {
    "type": "TEXT",
    "name": "eventName",
    "displayName": "Event Name",
    "simpleValueType": true,
    "help": "Canonical ClickTrail event names: lead.submitted, appointment.booked, appointment.attended, sale.completed, sale.refunded. Any custom name is accepted.",
    "valueHint": "{{DLV - event name}}",
    "valueValidators": [
      { "type": "NON_EMPTY" }
    ]
  },
  {
    "type": "TEXT",
    "name": "eventId",
    "displayName": "Event ID (deduplication)",
    "simpleValueType": true,
    "help": "Optional unique ID for this event occurrence. Repeated tag firings with the same ID are suppressed client-side and deduplicated downstream by ClickTrail.",
    "valueHint": "{{ClickTrail Event ID}}"
  },
  {
    "type": "SELECT",
    "name": "objectType",
    "displayName": "Object Type",
    "simpleValueType": true,
    "selectItems": [
      { "value": "none", "displayValue": "None" },
      { "value": "lead", "displayValue": "Lead" },
      { "value": "booking", "displayValue": "Booking" },
      { "value": "order", "displayValue": "Order" },
      { "value": "contact", "displayValue": "Contact" }
    ],
    "defaultValue": "none"
  },
  {
    "type": "TEXT",
    "name": "objectId",
    "displayName": "Object ID",
    "simpleValueType": true,
    "help": "The lead / booking / order / contact identifier associated with this event.",
    "enablingConditions": [
      { "paramName": "objectType", "paramValue": "none", "type": "NOT_EQUALS" }
    ]
  },
  {
    "type": "TEXT",
    "name": "eventValue",
    "displayName": "Value",
    "simpleValueType": true,
    "help": "Numeric monetary or lead value. Non-numeric values are ignored."
  },
  {
    "type": "TEXT",
    "name": "currency",
    "displayName": "Currency",
    "simpleValueType": true,
    "help": "ISO 4217 currency code sent alongside Value.",
    "valueHint": "BRL | EUR | USD"
  },
  {
    "type": "TEXT",
    "name": "attributionVariable",
    "displayName": "Attribution Object",
    "simpleValueType": true,
    "help": "Set to the ClickTrail Attribution variable, e.g. {{ClickTrail Attribution}}. Accepts an object or a JSON string; attached to the payload as attribution.",
    "valueHint": "{{ClickTrail Attribution}}"
  },
  {
    "type": "CHECKBOX",
    "name": "includePageData",
    "checkboxText": "Include current page location in the payload",
    "simpleValueType": true,
    "defaultValue": true
  },
  {
    "type": "SIMPLE_TABLE",
    "name": "customProperties",
    "displayName": "Custom Event Properties",
    "subParams": [
      {
        "type": "TEXT",
        "name": "name",
        "displayName": "Property Name",
        "simpleValueType": true
      },
      {
        "type": "TEXT",
        "name": "value",
        "displayName": "Value",
        "simpleValueType": true
      }
    ],
    "help": "Optional extra properties merged into payload.properties."
  },
  {
    "type": "GROUP",
    "name": "advancedGroup",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "CHECKBOX",
        "name": "debug",
        "checkboxText": "Log the pushed payload to the console (preview/debug only)",
        "simpleValueType": true,
        "defaultValue": false
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

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



___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "dataLayer"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              },
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "clicktrail_gtm_seen_events"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "isRequired": true
  }
]

___TESTS___

scenarios: []


___NOTES___

Maintained by Vizuh OU as part of ClickTrail.
Repository: https://github.com/vizuh/clicktrail-gtm-event-tag
