# Contributing

Contributions are welcome when they preserve the purpose of this repository:
a local, offline photo and video review app.

Please keep these boundaries in mind:

- Do not add accounts, cloud sync, subscriptions, paywalls, tracking, or a
  network SDK without first documenting the change and its privacy impact.
- Never commit Apple signing certificates, provisioning profiles, API keys,
  service credentials, or real user media.
- Preserve local data migration behavior and the shared App Group contract used
  by the widget.
- Test changes on both a simulator and a physical device when they touch photo
  permissions, video playback, Photos changes, or widget data.
- Describe behavior changes, migration risks, and manual test steps in pull
  requests.

By submitting a contribution, you agree that it may be distributed under the
license in `LICENSE`.
