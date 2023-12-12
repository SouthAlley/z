/*
引用地址https://raw.githubusercontent.com/wf021325/qx/main/js/qimao.js
*/
if ($request.url.includes("/api/v1/extra/init")) {
    var obj = JSON.parse($response.body);
    obj.data.reader_floats = [];
    obj.data.reader_top_banner = [];
    $done({body : JSON.stringify(obj)});
  }else if ($request.url.includes("/api/v3/user/my-center")) {
    var obj = JSON.parse($response.body);
   obj.data.func_area.forEach((element, index, array) => {
      if (index !== 0 && index !== array.length - 1) {
          obj.data.func_area[index].list = [];
      obj.data.func_area[index].first_title = "";
      }else if(index == array.length - 1){
     obj.data.func_area[index].list = obj.data.func_area[index].list.filter((_, _index) => ![2, 3, 5, 6].includes(_index));
    }
   });
    $done({body : JSON.stringify(obj)});
  }