/*
脚本引用 https://raw.githubusercontent.com/zirawell/Ad-Cleaner/main/Collection/js/flyert.js
脚本时间 2024-07-10 08:18:08
*/
let body = $response.body;
let headers = $response.headers;
const isResponse = typeof $response !== "undefined";
const isJson = headers["Content-Type"] == "application/json";
if(isResponse && isJson){
  let obj = JSON.parse(body);
  if(obj?.Variables){
    let variables = obj.Variables;
    if(variables.data && variables.data.adv){
      variables.data.adv={};
    }
  }
  body = JSON.stringify(obj);
  $done({ body });
}else{
  $done();
}