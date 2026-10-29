# v0-clone

Vercel's [v0 clone](https://github.com/vercel/v0-sdk/tree/main/examples/v0-clone)
— the v0 SDK's example app: a v0-style chat that builds apps through the
[v0 Platform API](https://v0.app/docs/api/platform), with a live preview served
from an isolated origin, Design Mode, file, ZIP and GitHub imports and
one-click deploys — as **two Cloudflare Workers** built by
[`@opennextjs/cloudflare`](https://opennext.js.org/cloudflare): the host app and
its preview proxy, each on its own origin, deployed per environment through
[Orun](https://github.com/sourceplane/orun), and packaged, once it is built, as
an **Orun baseline**.

Being built in reviewed steps; the plan and its status are in
[`specs/epics/v0-clone`](specs/epics/v0-clone/README.md).

The v0 SDK and its example are © Vercel, Inc., under the Apache License 2.0.
