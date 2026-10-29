// Where the v0 API calls go. Unset — always, unless an owner sets it — every
// call goes to v0's API, exactly as upstream. V0_API_BASE_URL points them at
// another origin with the same paths: the stand-in v0 API the end-to-end test
// serves (testing/), or an egress proxy in front of v0.
const V0_API_ORIGIN = 'https://api.v0.dev'

export const v0Fetch: typeof fetch = (input, init) => {
  const base = process.env.V0_API_BASE_URL
  if (!base) return fetch(input, init)

  const request = new Request(input, init)
  const url = new URL(request.url)
  if (url.origin !== V0_API_ORIGIN) return fetch(request)

  return fetch(new Request(new URL(url.pathname + url.search, new URL(base).origin), request))
}
