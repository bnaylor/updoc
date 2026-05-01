To make CLI/agent requests to the Moma API, the specific authentication tokens and mechanisms depend on how you are calling the API:

1.  **Human Users via Stubby/CLI:**
    *   You can typically call the Moma Search API using your standard **LOAS credentials** obtained via `gcert`.
    *   For testing, you can use the script: `/google/src/head/depot/google3/moma/search/api/example/send_search_request.sh`
    *   If using tools like rpcStudio, you need to provide a **Prod GaiaMint** as the End User Credential.

2.  **Human Users via HTTP/JSON (e.g., `sso_client`):**
    *   These calls go through Uberproxy and use **Uberproxy Auth**, which relies on your CorpSSO login.
    *   An **API Key** is also required to identify the calling application. A shared key is available for staging, but you'll need your own for production use.

3.  **Agents / Borg Jobs:**
    *   Applications running on Borg must forward End User Credentials (EUCs).
    *   The Borg role needs membership in specific Ganpati groups (e.g., `mdb/moma-search-api-general-access-clients`).
    *   Moma uses **UpTicks** (from Uberproxy) to enforce tiered access based on device trust. Frontends calling Moma must enable UpTicks (see go/uptick-usage). Moma then exchanges the UpTick for a **GaiaMint**.

4.  **Gemini CLI / Agents using Moma MCP Servers:**
    *   According to go/moma-mcp-doc, you need to:
        1.  Enable the **Corp Moma Search API** in your LOAS-associated Google Cloud project through Pantheon.
        2.  When adding the Moma tool to the Gemini CLI, ensure the setup uses your LOAS credentials to obtain a **TransactDAT**. This is typically handled by a flag like `--use_loas_transact_dat=True` in the tool configuration:
            ```bash
            gemini mcp add --scope=user moma-search-api /google/bin/releases/corp-mcp-proxy/server.par --mcp_server=blade:moma_search.api.momasearchapi-prod --use_loas_transact_dat=True
            ```

In summary, you don't need a single "token" but rather rely on Google's standard internal authentication infrastructure, including LOAS, GaiaMints, CorpSSO, and TransactDATs, depending on the call method. For CLI/agent use cases like with Gemini CLI, the key steps are enabling the API in your cloud project and using a mechanism to exchange your LOAS credentials for a TransactDAT.

### Sources:

* [Moma Platform: Search API - Moma Search](https://g3doc.corp.google.com/company/teams/moma/platform/api.md)
* [Moma MCP Server Details - Moma Search](https://g3doc.corp.google.com/moma/search/g3doc/mcp/server_details.md)
* [Authentication and Authorization - Moma Search](https://g3doc.corp.google.com/moma/search/g3doc/auth/moma_auth.md)
* [Moma Search API: Technical Documentation - Moma Search](https://g3doc.corp.google.com/moma/search/g3doc/api/index.md)
* [Client-side Authentication Guide - One Platform](https://g3doc.corp.google.com/google/g3doc/oneplatform/client-auth.md)

