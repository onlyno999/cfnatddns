# cfnatddns cfnat


直接下载那个压缩包，CFNATDDNS， Windows版本运行完事。修改里面的配置文件里面有说明。

DNS绑定域名
若希望使用域名而非IP：
在Cloudflare中添加子域名（如best.yourdomain.zone.id），
确保已挂靠到Cloudflare。
在CfnatN中填写子域名、区域ID和Global API Key。
运行工具，优选IP将自动绑定到子域名，生成专属优选域名。
绑定后需等待生效（通常几分钟到十几分钟，因网络环境而异）。
生效后，将节点配置中的IP替换为优选域名，其他参数不变。

登录用户名 email 就是你的cf的登录邮箱。

登录进去以后点右上角。小人头。你就会看到api，查看就对了。

![image](https://img.picui.cn/free/2025/05/25/68320ef5a23d3.jpg)
区域id，点击域名，点击概述，拉到最下面就会看到一个区域id复制下。


![image](https://img.picui.cn/free/2025/05/25/68320ef5d63d4.jpg)

最后点击域名，点击dns。新增一个 A记录。二级域名。 Ip随便填吧，然后再把这个二级域名填入到填入到配置文件。
最后一次更新，以后没得更新了。




完全模拟本地:
打包好的下载地址:
https://wwss.lanzouq.com/i4LTD2y6p9vi


增加一个支持自定义多个dns直接同步：
https://wwss.lanzouq.com/i2bHb2y6p9pc


[![Powered by DartNode](https://dartnode.com/branding/DN-Open-Source-sm.png)](https://dartnode.com "Powered by DartNode - Free VPS for Open Source")
