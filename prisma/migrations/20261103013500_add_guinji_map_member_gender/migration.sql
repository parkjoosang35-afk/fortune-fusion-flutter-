-- Safe additive migration: add nullable gender column to map_member (GuinjiMapMember)
-- This does not affect existing rows; existing data remains unchanged (gender = NULL for legacy rows).
ALTER TABLE "map_member" ADD COLUMN "gender" TEXT;
