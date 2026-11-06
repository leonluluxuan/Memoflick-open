# Contributing / 参与贡献

## English

Contributions are welcome when they preserve the purpose of this repository:
a local, offline-first photo and video review app.

- Do not add accounts, cloud sync, subscriptions, paywalls, tracking, or a
  network SDK without documenting the change and its privacy impact first.
- Never commit Apple signing certificates, provisioning profiles, API keys,
  service credentials, or real user media.
- Preserve local data migration behavior and the shared App Group contract
  used by the widget.
- Test changes on a simulator and a physical device when they touch Photos
  permissions, video playback, Photos changes, or widget data.
- Describe behavior changes, migration risks, and manual test steps in pull
  requests.

By submitting a contribution, you agree that it may be distributed under the
license in `LICENSE`.

## 中文

欢迎在不改变本项目定位的前提下贡献代码：这是一个本地优先、离线可用的照片与视频整理应用。

- 未经说明和隐私影响评估，不要加入账号、云同步、订阅、付费墙、追踪或网络 SDK。
- 不要提交 Apple 签名证书、Provisioning Profile、API Key、服务凭据或真实用户媒体。
- 保持本地数据迁移逻辑，以及 App 与小组件共用的 App Group 约定。
- 涉及照片权限、视频播放、Photos 变更或小组件数据时，请同时在模拟器和真机验证。
- 在 Pull Request 中说明行为变化、迁移风险和手工测试步骤。

提交贡献即表示你同意该贡献可以按照 `LICENSE` 中的许可证分发。
