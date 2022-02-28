# 修改的地方：

- 没有实例化 TransparentUpgradeableProxy 合约，仅仅实例化了 implements 合约
因为 attach 方法跟 getContractAt 方法其实差不多，只是前者已经指定了 abi，后者要在参数里指定 abi。使用 attach 方法的操作相当于：先创建一个 QBridge 指定到 implement 地址，然后又重新指定到 proxy 地址。所以这里改成了用 implement 合约的 abi 去调用 proxy 地址，也就是直接用 QBridge abi 指定到 proxy 地址。那么调用 proxy 地址时候，直接转发到 Qbridge 合约，也就对应上了 abi。

- 没有在本地编译全部合约
「接着需要compile合约，虽然我们是从archinve node上fetch contract的信息和数据，但archive node 并没有储存contract的逻辑，bytecode这些东⻄，所以我们仍然需要在本地编译合约」这句话可能是有点问题的。
外部合约都是现成的字节码，直接从主网拉的，不用编译，要编译的代码有两种：
   1. 攻击合约。一般简单的攻击在 js 脚本里面搞定，但如果复杂的攻击，js 里面搞不定的，比如需要重入、回调的，就需要定义在合约里面，就是所谓的 poc 合约。
   2. js 里面 getContractAt 的合约，需要有对应的合约。这个合约名要两边一致，以 getContractAt 的参数去寻找，需要合约里面实现了。
   3. 注意：对于2里面的合约，我们根据 abi to sol 即可，只需要实现接口即可，一会儿进行接口调用。而不需要重新编译主网合约。进行接口调用的接口文件一般没有 solc 的版本限制，自己随便定义版本即可。


# 运行结果：
<img width="992" alt="image" src="https://user-images.githubusercontent.com/95465284/155994483-419d923e-ce1c-4b01-b9bd-571a6767eaf4.png">
<img width="995" alt="image" src="https://user-images.githubusercontent.com/95465284/155994599-f422a10a-9ba7-4cdc-b139-bdd15de8d5fe.png">
可见 deposit 事件被成功触发了。
