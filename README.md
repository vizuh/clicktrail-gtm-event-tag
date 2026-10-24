# clicktrail-gtm-event-tag

> **ClickTrail is the open-source attribution handoff layer that keeps observed acquisition context attached to conversion records inside the stack you own.**

This template exposes that handoff to a site-owned Google Tag Manager
`dataLayer`; it does not inject provider pixels or certify downstream delivery.

Sends lead, booking, order and contact events as a canonical,
schema-versioned ClickTrail payload. The tag **pushes to the page
`dataLayer`** under the `clicktrail` event name; it does not inject scripts,
fire pixels, or touch cookies.

[gallery]: https://developers.google.com/tag-platform/tag-manager/templates/gallery

## Why a dataLayer push?

- Tightly permissioned: the template requests only `access_globals`
  (`dataLayer` push + one namespaced dedup key), optional `get_url`, and
  debug logging.
- Transport stays with ClickTrail: the ClickTrail browser adapter
  ([clicktrail-js][js]) or the WordPress plugin consumes the payload and owns
  delivery, retries, and signing.
- Downstream GTM tags (GA4, Ads conversions) can also listen for the
  `clicktrail` event and forward fields without re-scraping the page.

[js]: https://github.com/vizuh/clicktrail-js

## Parameters

| Parameter | Required | Notes |
|---|---|---|
| ClickTrail Site ID | yes | Site/tenant ID from ClickTrail settings |
| Event Name | yes | One canonical name: `page_view`, `form_started`, `lead_created`, `lead_qualified`, `booking_created`, `booking_completed`, `sale`, `refund`, `consent_updated` |
| Event ID | no | Unique per occurrence; duplicates are suppressed client-side and deduplicated downstream |
| Object Type / ID | no | `lead`, `booking`, `order`, `contact` + its identifier |
| Value / Currency | no | Numeric value + ISO 4217 code |
| Attribution Object | no | Set to `{{ClickTrail Attribution}}` (this project's companion variable) |
| Include page location | yes (default on) | Adds `payload.page.location` |
| Custom Event Properties | no | Free-form name/value table merged into `payload.properties` |

## Payload shape

```json
{
  "schema_version": "1.2.0",
  "source": "gtm",
  "site_id": "<site id>",
  "event": {
    "name": "lead_created",
    "id": "<event id>",
    "object_type": "lead",
    "object_id": "<lead id>",
    "value": 1990.0,
    "currency": "BRL"
  },
  "attribution": { "...": "from {{ClickTrail Attribution}}" },
  "page": { "location": "https://example.com/obrigado" },
  "properties": { "...": "custom properties" }
}
```

Legacy dotted names remain accepted during migration and normalize before the
dataLayer push; custom names pass through unchanged.

## Forwarding to GA4: reserved field names and catch-all tags

If GA4 Event tags read the `clicktrail` push, **never use a Google tag field
name as an event parameter name**:

`session_id`, `client_id`, `user_id`, `session_number`,
`engagement_time_msec`, `timestamp_micros`, `page_location`, `page_referrer`.

The Google tag reads these as its own fields, not as custom parameters. For
example, a `session_id` parameter is sent as GA4's session (`sid`) and
overrides the `_ga_<property>` session cookie. GA4 then reports sessions
without `session_start`, traffic source `(not set)`, and conversions land in
Unassigned. Use a prefixed name such as `ct_session_id` instead. The same
rule applies to names you add under *Custom Event Properties* and forward.

**Catch-all GA4 Event tags.** A common setup is one GA4 Event tag with event
name `{{Event}}` that fires on every custom event except `gtm.*`. That tag
would also send a GA4 event named `clicktrail`. If the ClickTrail browser
SDK runs on the same page, it would also forward the SDK's `ct_page_view` push.
Exclude both (`{{Event}}` does not match RegEx
`^(gtm\..*|clicktrail|ct_page_view)$`). Forward ClickTrail events from a
dedicated tag that reads `clicktrail_event.event.name` instead. Skip
`page_view` there: the Google tag already sends its own page views.

Background: [vizuh/clicktrail-js#48](https://github.com/vizuh/clicktrail-js/issues/48).

## Install & submit

1. In Google Tag Manager: **Templates → Import** → select `template.tpl`.
2. Create a tag from *ClickTrail Event Tag*, fill in the parameters.
3. Preview with Tag Assistant and confirm the `clicktrail` dataLayer event.

### Gallery submission checklist

- [ ] `template.tpl`, `metadata.yaml`, Apache-2.0 `LICENSE` at repo root, `main` branch
- [ ] GitHub Issues enabled on the repository
- [ ] Replace the placeholder `sha` in `metadata.yaml` with the release commit SHA (`git rev-parse HEAD`)
- [ ] Import into GTM, run template unit tests, then submit via the [Community Template Gallery form][form]

[form]: https://developers.google.com/tag-platform/tag-manager/templates/gallery#submit

## Consent

This tag follows the consent state already supplied by the site's CMP through
GTM Consent Mode (`setDefaultConsentState` / `updateConsentState`). It does
not render any consent UI; ClickTrail is not a Consent Management Platform.

## Repository structure

Follows the [Stape GTM standards](https://github.com/stape-io/gtm-standards)
(GTMS-4/5): the readable template code lives in [`template.js`](template.js)
and is mirrored inside `template.tpl`; `tests.yaml` mirrors the `___TESTS___`
section. Keep both files in sync on every change.

## License

Apache License 2.0 — see [LICENSE](LICENSE).

### GTM Gallery Status
⚪ Not listed yet
