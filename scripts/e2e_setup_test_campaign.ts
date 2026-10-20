import { prisma } from "../src/lib/db";
import { createCampaign } from "../src/lib/bokju-coupon-service";

async function main() {
  const now = new Date();
  const validTo = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);
  const { campaignId } = await createCampaign(
    {
      title: "[E2E-Playwright] 디자인 정렬 테스트용",
      grantAmount: 10,
      issueType: "INDIVIDUAL",
      targetAudience: "ALL",
      useLimitPerMember: 1,
      totalIssueLimit: 100,
      validFrom: now,
      validTo,
      distributionMethod: "DIRECT",
    },
    "e2e-script"
  );
  console.log("CAMPAIGN_ID=" + campaignId);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
