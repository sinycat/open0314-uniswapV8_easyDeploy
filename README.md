##  内容说明

####    1. 创建新项目,forge init
####    2. 安装或复制uniswapv2 contracts库文件
####    3. 调整版本或安装已调整过的版本
####    4. 编制部署合约脚本 分为两个运行函数
####    5. 运行部署脚本 注意将UniswapV2Factory中PAIR_HASH写入UniswapV2Library中的对应位置
####    6. 编制测试脚本
####    7. 测试UniswapV2Router中各函数,主要是addLiquidity和removeLiquidity相关函数
####    8. 编制MyDex合约,引入UniswapV2Router,UniswapV2Factory,WETH9,RNT.
####    9. 测试MyDex合约.


##  重点地方

####    1. 版本问题
####    2. UniswapV2Factory中PAIR_HASH写入UniswapV2Library

##  测试成功截图
<img width="731" alt="测试成功截图3 16" src="https://github.com/user-attachments/assets/fd76ea5a-3ff5-4964-9eaf-4c29c2a4d0ec" />


<img width="714" alt="测试成功截图3 17" src="https://github.com/user-attachments/assets/d4b12847-6290-4e1c-84cb-2edaf490dc10" />
