/**
 * Privacy route contract implemented by runtime/server.mjs.
 * POST /api/v1/privacy/account-close authenticates the server-derived user,
 * anonymizes account identity and archives rather than deletes business records.
 */
export const privacyRoutes = ['POST /api/v1/privacy/account-close'] as const
