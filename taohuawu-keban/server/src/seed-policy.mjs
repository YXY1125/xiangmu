export function seedReady(seed){
  return seed.productionReleaseApproved===true&&
    seed.entities.Material.every(m=>m.status!=='published'||m.licenseRecord?.scope==='in_app_composition'&&m.licenseRecord?.releaseReview==='approved')&&
    seed.entities.Artwork.every(a=>a.visibility!=='public'||a.rightsEvidence?.releaseReview==='approved')&&
    seed.entities.KnowledgeArticle.every(a=>a.status!=='published'||a.factCheckStatus==='verified'&&a.sourceRecords?.length>0);
}
