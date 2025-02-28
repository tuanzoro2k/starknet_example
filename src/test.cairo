use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemeCoin<TState> {
    fn create_pool(ref self: TState,
        name: felt252, symbol: felt252, pool_details: felt252, config_index: felt252,
        router: felt252, start_time: u64, buy_fee_rate: u256, sell_fee_rate: u256,
        max_buy_amount: u256, delay_buy_time: felt252,
        initial_buy_amount: felt252);
    fn set_master_config(ref self: TState, fee_receiver: ContractAddress, fee_bps: u256, ref_bps: u256, pool_token: ContractAddress);
    fn set_pool_config(ref self: TState, initial_virtual_base_reserve: u256, initial_virtual_quote_reserve:u256, total_selling_base_amount: u256, max_listing_base_amount: u256, max_listing_quote_amount: u256, listing_fee: u256);
    fn buy(ref self: TState,  token: ContractAddress,
        referrer: ContractAddress,
        amount_in: u256,
        min_amount_out: u256 );
    fn sell(ref self: TState, token: ContractAddress,referrer: ContractAddress,amount_in: u256,min_amount_out: u256);
}
 
#[starknet::contract]
pub mod MemeCoin {
    use core::num::traits::Zero;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess,StoragePathEntry};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address,syscalls::deploy_syscall};
    use starknet::class_hash::ClassHash;
    use starknet::get_block_timestamp;
    use hello_starknet::libAthene::{ILibAtheneDispatcherTrait, ILibAtheneLibraryDispatcher};

    const FEE_DENOMINATOR: u256 = 10000;
    #[storage]
    struct Storage {
        pool_info: Map<ContractAddress,PoolInfo>,
        master_config: MasterConfig,
        pool_config: PoolConfig,
        lib_class_hash: starknet::ClassHash,
    }
    
    // Define the PoolInfo struct
   #[derive(Drop, Serde, Copy, starknet::Store)]

    pub struct PoolInfo {
    owner: ContractAddress,
    router: felt252,
    pool_details: felt252,
    state: felt252,
    virtual_base_reserve: u256,
    virtual_quote_reserve: u256,
    min_base_reserve: u256,
    min_quote_reserve: u256,
    max_listing_base_amount: u256,
    max_listing_quote_amount: u256,
    listing_fee: u256,
    start_time: u64,
    listed_at: felt252,
    buy_fee_rate: u256,
    sell_fee_rate: u256,
    max_buy_amount: u256,
    delay_buy_time: felt252,
    }

    #[derive(Drop, Serde, Copy, starknet::Store)]

    pub struct PoolConfig {
        initial_virtual_base_reserve: u256,
        initial_virtual_quote_reserve: u256,
        total_selling_base_amount: u256,
        max_listing_base_amount: u256,
        max_listing_quote_amount: u256,
        listing_fee: u256
    }

    #[derive(Drop, Serde, Copy, starknet::Store)]

    pub struct MasterConfig {
        fee_receiver: ContractAddress,
        fee_bps: u256,
        ref_bps: u256,
        pool_token: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        TokenCreated: TokenCreated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TokenCreated {
        #[key]
        pub token: felt252,
        pub user: ContractAddress,
        pub base_reserve: u256,
        pub quote_reserve: u256,
        pub timestamp: felt252,
        pub pool_details: felt252,
        pub start_time: u64,
        pub buy_fee_rate: u256,
        pub sell_fee_rate: u256,
        pub max_buy_amount: u256,
        pub delay_buy_time: felt252,
        pub max_listing_quote_amount: u256,
        pub listing_fee: u256,
    }

    #[abi(embed_v0)]
    impl MemeCoinImpl of super::IMemeCoin<ContractState> {
        fn set_master_config(ref self: ContractState, fee_receiver: ContractAddress, fee_bps: u256, ref_bps: u256, pool_token: ContractAddress) {
            self.master_config.write(MasterConfig{
                fee_receiver,
                fee_bps,
                ref_bps,
                pool_token
            })
        }

        fn set_pool_config(ref self: ContractState, initial_virtual_base_reserve: u256, initial_virtual_quote_reserve:u256, total_selling_base_amount: u256, max_listing_base_amount: u256, max_listing_quote_amount: u256, listing_fee: u256){
            self.pool_config.write(PoolConfig{
                initial_virtual_base_reserve,
                initial_virtual_quote_reserve,
                total_selling_base_amount,
                max_listing_base_amount,
                max_listing_quote_amount,
                listing_fee
            })
        }

        fn create_pool(
            ref self: ContractState,
            name: felt252, symbol: felt252, pool_details: felt252, config_index: felt252,
            router: felt252, start_time: u64, buy_fee_rate: u256, sell_fee_rate: u256,
            max_buy_amount: u256, delay_buy_time: felt252,
            initial_buy_amount: felt252
        ) {
            // let config = get_pool_config(config_index);
            // assert(config.initial_virtual_base_reserve > 0, "Invalid config");
            // assert(buy_fee_rate <= FEE_DENOMINATOR, "Invalid buy fee rate");
            // assert(sell_fee_rate <= FEE_DENOMINATOR, "Invalid sell fee rate");
            let contract_class_hash: ClassHash = 0x0125408b42bbb4bc9d00148d2879f12b6e73f7b06ebdf8d17baab6d4b60f5e65.try_into().unwrap();
            let mut constructor_calldata: Array::<felt252> = array![name, symbol];
            let (deployed_address, _) = deploy_syscall(
                contract_class_hash, 0, constructor_calldata.span(), false,
            )
                .unwrap();
            
            self.pool_info.write( deployed_address,PoolInfo {
                owner: get_caller_address(),
                router,
                pool_details,
                state: 0,
                virtual_base_reserve: self.pool_config.initial_virtual_base_reserve.read(),
                virtual_quote_reserve: self.pool_config.initial_virtual_quote_reserve.read(),
                min_base_reserve: self.pool_config.initial_virtual_base_reserve.read() - self.pool_config.total_selling_base_amount.read(),
                min_quote_reserve:self.pool_config.initial_virtual_quote_reserve.read(),
                max_listing_base_amount: self.pool_config.max_listing_base_amount.read(),
                max_listing_quote_amount: self.pool_config.max_listing_quote_amount.read(),
                listing_fee: self.pool_config.listing_fee.read(),
                start_time,
                listed_at: 0,
                buy_fee_rate,
                sell_fee_rate,
                max_buy_amount,
                delay_buy_time,
            });

            self.emit(TokenCreated {
                token: 0,
                user: get_caller_address(),
                base_reserve: self.pool_config.initial_virtual_base_reserve.read(),
                quote_reserve: self.pool_config.initial_virtual_quote_reserve.read(),
                timestamp: 0,
                pool_details,
                start_time,
                buy_fee_rate,
                sell_fee_rate,
                max_buy_amount,
                delay_buy_time,
                max_listing_quote_amount: self.pool_config.max_listing_quote_amount.read(),
                listing_fee: self.pool_config.listing_fee.read(),
            });
        }

        fn buy(ref self: ContractState,  token: ContractAddress,referrer: ContractAddress,amount_in: u256,min_amount_out: u256 ){
                self._buy(
                    token,
                    referrer,
                    amount_in,
                    min_amount_out,
                    false);
        }
        fn sell(ref self: ContractState, token: ContractAddress,referrer: ContractAddress,amount_in: u256,min_amount_out: u256) {
            let pool_token = self.pool_info.read(token);
            let pool_option = Option::Some(pool_token);
            assert!(pool_option.is_some(), "Pool not found");
            assert!( get_block_timestamp() >= pool_token.start_time, "Not valid start time");
            let (amount_out,amount_out_less_fee,total_fee,platform_fee,trade_fee) = self._get_amount_out_with_pool_info(pool_token, amount_in, false);
            assert!(amount_out_less_fee>= min_amount_out, "Insufficent output amount");
            self._take_fee(platform_fee, trade_fee, pool_token.owner, referrer);
            let mut pool = self.pool_info.entry(token);
            pool.virtual_base_reserve.write(pool_token.virtual_base_reserve + amount_in);
            pool.virtual_quote_reserve.write(pool_token.virtual_quote_reserve - amount_out);
            assert!(pool_token.virtual_quote_reserve >= pool_token.min_quote_reserve,"Invalid quote reserve calculation");
            ILibAtheneLibraryDispatcher{class_hash: self.lib_class_hash.read()}.transferFrom(token, get_caller_address(),get_contract_address(),amount_in);
            ILibAtheneLibraryDispatcher{class_hash: self.lib_class_hash.read()}.transfer(self.master_config.pool_token.read(), get_caller_address(), amount_out);
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
    fn _buy(
        ref self: ContractState,
        token: ContractAddress,
        referrer: ContractAddress,
        amount_in: u256,
        min_amount_out: u256,
        is_initial: bool
    ) {
        let pool_token = self.pool_info.read(token);
        let pool_option = Option::Some(pool_token);
        assert!(pool_option.is_some(), "Pool not found");
        assert!( get_block_timestamp() >= pool_token.start_time, "Not valid start time");
        assert!(amount_in <= pool_token.max_buy_amount, "Exceeded max buy");
        assert!(pool_token.listed_at == 0, "Invalid state");
        assert!(pool_token.virtual_base_reserve > pool_token.min_base_reserve);
        assert!(pool_token.virtual_quote_reserve < pool_token.min_quote_reserve + pool_token.max_listing_quote_amount + pool_token.listing_fee);
        let (amount_out,amount_out_less_fee,total_fee,platform_fee,trade_fee) = self._get_amount_out_with_pool_info(pool_token, amount_in, true);

        ILibAtheneLibraryDispatcher{class_hash: self.lib_class_hash.read()}.transferFrom(self.master_config.pool_token.read(), get_caller_address(),get_contract_address(),amount_in +total_fee );
        assert!(amount_out >= min_amount_out, "Insufficent output amount");
        self._take_fee(platform_fee, trade_fee, pool_token.owner, referrer);
        let mut pool = self.pool_info.entry(token);
        pool.virtual_quote_reserve.write(pool_token.virtual_quote_reserve + amount_in);
        pool.virtual_base_reserve.write(pool_token.virtual_base_reserve - amount_out);
        assert!(pool_token.virtual_base_reserve >= pool_token.min_base_reserve,"Invalid base reserve calculation");
        ILibAtheneLibraryDispatcher{class_hash: self.lib_class_hash.read()}.transfer(token, get_caller_address(), amount_out);
    }

    fn _get_amount_out_with_pool_info(ref self: ContractState, pool_info: PoolInfo, amount_in: u256, is_buy: bool) -> (u256, u256,u256, u256, u256){
        let mut platform_fee = 0;
        let mut trade_fee = 0;
        let mut total_fee = 0;
        if(is_buy){ 
            platform_fee = amount_in * self.master_config.fee_bps.read() / FEE_DENOMINATOR;
            trade_fee = amount_in * pool_info.buy_fee_rate / FEE_DENOMINATOR;
            total_fee = platform_fee + trade_fee;
        }
        let mut amount_out = ILibAtheneLibraryDispatcher{class_hash: self.lib_class_hash.read()}.get_amount_out(
            amount_in,
            if is_buy {
                pool_info.virtual_quote_reserve
            } else {
                pool_info.virtual_base_reserve
            },
            if is_buy {
                pool_info.virtual_base_reserve
            } else {
                pool_info.virtual_quote_reserve
            }
        );
        let mut remaining =0;
        remaining = if is_buy {
            pool_info.virtual_base_reserve - pool_info.min_base_reserve
        } else {
            pool_info.virtual_quote_reserve - pool_info.min_quote_reserve
        };

        if(amount_out > remaining){
            amount_out = remaining;
        }

        let mut amount_out_less_fee = amount_out;

        if(is_buy == false){
            platform_fee = amount_out * self.master_config.fee_bps.read() / FEE_DENOMINATOR;
            trade_fee = ((amount_out - platform_fee) * pool_info.sell_fee_rate) / FEE_DENOMINATOR;
            total_fee = platform_fee + trade_fee;
            amount_out_less_fee = amount_out - total_fee;
        }

        return (amount_out,amount_out_less_fee,total_fee,platform_fee,trade_fee);
    }

    fn _take_fee(ref self: ContractState, platform_fee: u256, trade_fee: u256, owner: ContractAddress, referrer: ContractAddress) {
        let mut referrer_fee =0;
        if(referrer != Zero::zero()){
            referrer_fee =
            (platform_fee * self.master_config.ref_bps.read()) /
            FEE_DENOMINATOR;

            ILibAtheneLibraryDispatcher{class_hash: self.lib_class_hash.read()}.transfer(
            self.master_config.pool_token.read(),
            referrer,
            referrer_fee
            );
        }
    }

}
}

