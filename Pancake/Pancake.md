BNB smart chain 上面的知名 dex 项目 PancakeSwap，其代码具有重要参考学习意义。
本文对其 MasterChef 合约 [0x73feaa1ee314f8c655e354234017be2193c9e24e](https://bscscan.com/address/0x73feaa1eE314F8c655E354234017bE2193C9E24E#code) 的代码进行逐函数分析。


# 1、一些变量和构造器函数
```
contract MasterChef is Ownable {   //继承了 Owner 合约，这个合约主要是关于合约 owner 的一些函数，包括 onlyOwner 修饰符、transferOwner 这些
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    //每一个用户的信息
    struct UserInfo {               //这个结构体定义了池子里面的单个用户的相关信息
        uint256 amount;             //amount：用户质押了多少 LP tokens
        
        //rewardDebt：指用户不可提取的那部分奖励。
        //为什么呢？因为用户的奖励是一个减法运算，大概是用户取出奖励时候的奖励总数-用户存进来时候的奖励总数。
        //所以这个值就计算了用户存进来时候的奖励总数，相当于一个存进来之前的存档，用于最后计算差值。
        //这里看不懂的话没关系，后面还会在函数中具体看。
        uint256 rewardDebt;           
    }

    //每一个池子的信息
    struct PoolInfo {
        IBEP20 lpToken;           //LPToken 的 地址 
        
        // allocPoint：大概翻译为分配点。就是说每个区块都在挖指定的奖励币，在这里是 cake（为什么是 cake 后面会说到）。
        //然后挖出来的 cake tokens 怎么分呢？分有两个层级，一是 pool 池子，二是 user 用户。先是分给池子，然后分给池子里的用户。
        //这个变量就是说池子分配的比例。池子也是按照比例分的：allocPoint/totalAllocPoints
        //现在应该很好理解了，allocPoint 指单个池子所占的比例，totalAllocPoints 是所有池子加起来一共是多少分配点
        uint256 allocPoint;       
        
        uint256 lastRewardBlock;  //上一次分配 CAKE 代币的区块号
        
        uint256 accCakePerShare;  //累计每个 LP Token 可分到的 Cake Token 数量，为了防止小数出现，会乘以1e12
                                  //这个值最终会用在单个用户的奖励计算中
    }

    //cake 代币合约
    CakeToken public cake;
    
    //SYRUP 代币合约。
    //在[官方文档 FAQ](https://docs.pancakeswap.finance/help/faq) 中，提到了 SYRUP 因为安全问题已被停用，不再是 PancakeSwap 的一部分
    //但链上我们又确实看到这个合约还在被使用，并且这个 masterchef 合约会调用 SYRUP 合约中的函数，masterchef 合约也没有部署更新的版本。
    //这个 SYRUP 代币没有价值，目前没有单价。
    //后面的分析我们可以看到，这个 syrup 合约被用作了 masterchef 的金库合约，用于转入转出 cake 代币。这个代币也仅仅作为一种对质押 CAKE 或者其他 lp token 的权益证明的凭据，本身无需有价值。
    SyrupBar public syrup;
    
    // 开发者地址，池子挖矿奖励的 10% 的 cake 代币会转到此地址
    address public devaddr;
    
    // 每个区块挖出的 cake 代币数量
    uint256 public cakePerBlock;
    
    //给早期挖矿者的奖励倍数，目前已经是 1 倍了，也就是后期了，没有额外的挖矿奖励倍数了
    //这个倍数跟区块有关，因而说是给“早期”挖矿者的奖励因数
    uint256 public BONUS_MULTIPLIER = 1;
    
    //迁移合约地址。用于改变池子的 lp token。只有 owner 才能赋值。
    //需要更换 LPtoken 的时候，owner 会设置 migrator，然后任何人都可以调用 migrate 函数来更换池子的 lp token。
    // 目前这个地址是 0x0，平时这个地址长期都是 0x0
    //这个 migrator 合约的权力非常大，也很危险，因为 masterchef 合约的全部 old lptoken 余额都会被 approve 给这个 migrator 合约
    IMigratorChef public migrator;

    // 池子列表。这里的 0 号池子很特殊，是 cake，因为 cake 本身也是一种 lp token，其他的都是别的 pair 的 lptoken
    PoolInfo[] public poolInfo;
    
    // 每个矿池中用户的信息
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    
    // 所有矿池的分配点之和
    //比如说，masterchef 里面 3 个 pool，每个 pool 的 allocPoint 都是 10，那么 totalAllocPoint 就是 30。现在加了第 4 个 pool，其 allocPoint 是 5，那么现在 totalAllocPoint 就是 35。
    uint256 public totalAllocPoint = 0;
    
    // 开始挖矿（cake）的区块高度
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        CakeToken _cake,
        SyrupBar _syrup,
        address _devaddr,
        uint256 _cakePerBlock,
        uint256 _startBlock
    ) public {
        cake = _cake;
        syrup = _syrup;
        devaddr = _devaddr;
        cakePerBlock = _cakePerBlock;
        startBlock = _startBlock;

        // 在构造器函数中，设定了 pool[0]，这就是所谓的 staking pool 质押池，后面会通过 enterStaking 和 leaveStaking 函数在这个质押池中存入和取出 cake。
        // accCakePerShare 为0，因为目前每个 lp token 也就是 cake 分配到的 cake 奖励还是 0 个
        staking pool
        poolInfo.push(PoolInfo({
            lpToken: _cake,
            allocPoint: 1000,
            lastRewardBlock: startBlock,
            accCakePerShare: 0
        }));

        totalAllocPoint = 1000;

    }
```

# 2、两个非常简单的函数

```
    //只有合约 owner 可以更新奖励倍数，一般是早期是一个大于 1 的倍数，后面变成1，就是没有额外的奖励了
    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    //返回这个 masterchef 中一共有多少个池子了
    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
```

# 3、必须放在一起讲的四个函数
```
    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }
    
    // 添加新矿池，指定矿池分配点、LP代币合约地址以及是否更新所有矿池，只有合约 owner 可以调用此函数
    function add(uint256 _allocPoint, IBEP20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accCakePerShare: 0
        }));
        updateStakingPool();
    }

    // Update the given pool's CAKE allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }
```

 //
        // We do some fancy math here. Basically, any point in time, the amount of CAKEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accCakePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accCakePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
