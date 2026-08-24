# clicktrail-gtm-event-tag

[ClickTrail](https://wordpress.org/plugins/click-trail-handler/) Event Tag for
Google Tag Manager — a [Community Template Gallery][gallery] submission.

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
| Event Name | yes | e.g. `lead.submitted`, `appointment.booked`, `sale.completed` |
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
    "name": "lead.submitted",
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
