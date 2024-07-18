let url = $request.url;
let responseBody = $response.body;

let data = JSON.parse(responseBody);

// 删除信息流轮播推广
data.respData?.infoData?.[1]?.rotateResource && delete data.respData.infoData[1].rotateResource;

// 删除悬浮窗
data.respData?.userRed && delete data.respData.userRed;

// 删除测一测手机能卖多少钱
data.respData?.bmNewInfo && delete data.respData.bmNewInfo;

// 删除我的钱包
data.respData?.itemGroupList?.[2]?.itemList?.[0]?.walletInfo && delete data.respData.itemGroupList[2].itemList[0].walletInfo;

// 去掉“我的钱包”和调整推荐工具数量
data.respData.itemGroupList = data.respData.itemGroupList.map(itemGroup => {
    // 去掉“我的钱包”
    if (itemGroup.groupType === 15) {
        return null; // 将groupType为15的元素置为null
    } else if (itemGroup.groupType === 3) { // 推荐工具只保留4个
        itemGroup.itemList = itemGroup.itemList.slice(0, 4);
    }
    return itemGroup;
})。filter(Boolean); // 过滤掉为null的元素

responseBody = JSON.stringify(data);

$done({body: responseBody});
