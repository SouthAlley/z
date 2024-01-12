// 2024-01-11 15:20

const url = $request.url;
const isResp = typeof $response !== "undefined";
let body = $response.body;

switch (isResp) {
  // 网易新闻
  case /^https:\/\/nex\.163\.com\/q/g.test(url):
    try {
      let obj = JSON.parse(body);
      if (obj?.ads?.length > 0) {
        obj.ads = [];
      }
      body = JSON.stringify(obj);
    } catch (error) {
      console.log(`网易新闻, 出现异常: ` + error);
    }
    break;
  default:
    $done({});
}

$done({ body });