-- CR003 user-approved app-owned extension; does not change migration001 or platform tables.
BEGIN;
CREATE TABLE thwkb_feedback (
  "id" uuid NOT NULL,
  "tenantId" text NOT NULL,
  "appId" text NOT NULL,
  "userId" text NOT NULL,
  "category" text NOT NULL CHECK ("category" IN ('suggestion','bug','content','other')),
  "body" text NOT NULL,
  "status" text NOT NULL CHECK ("status" IN ('submitted','reviewing','replied','closed')),
  "reply" text,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  PRIMARY KEY ("tenantId","appId",id)
);
CREATE INDEX thwkb_feedback_q0 ON thwkb_feedback ("tenantId","appId","userId","createdAt");
CREATE INDEX thwkb_feedback_q1 ON thwkb_feedback ("tenantId","appId","status","updatedAt");
INSERT INTO thwkb_migrations(version) VALUES ('002');
COMMIT;
