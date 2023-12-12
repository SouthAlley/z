/*
引用脚本https://raw.githubusercontent.com/toulanboy/scripts/master/ithome_ad/ithome_ad.js
脚本二改https://github.com/Keywos/rule/raw/main/JS/ithomes.js
*/
const isLoon = typeof $loon !== "undefined";
let lbt = true,
  zd = true,
  lbtAd = true;
if (isLoon) {
  zd = $persistentStore.read("移除置顶项") === "开启";
  lbtAd = $persistentStore.read("移除轮播图广告") === "开启";
  lbt = $persistentStore.read("移除全部轮播图") === "开启";
}
let FeedTypes = [];

let i = JSON.parse($response.body);
if (i?.data?.list) {
  if (lbtAd && !lbt) {
    for (const Type of i.data.list) {
      if (Type.feedType === 10002) {
        Type.feedContent.focusNewsData = Type.feedContent.focusNewsData.filter(
          (i) => {
            return i.isAd === false; // 轮播图广告
          }
        );
        break;
      }
    }
  }
  lbt && FeedTypes.push(10002); //轮播
  zd && FeedTypes.push(10003); //置顶
  i.data.list = i.data.list.filter((item) => {
    return (
      !FeedTypes.includes(item.feedType) &&
      !item.feedContent.smallTags?.[0].text.includes("广告")
    );
  });
}
$done({ body: JSON.stringify(i) });
