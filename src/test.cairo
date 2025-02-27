use starknet::ContractAddress;

#[starknet::interface]
pub trait IMemeCoin<TState> {
    fn create_pool(ref self: TState,
        name: felt252, symbol: felt252, pool_details: felt252, config_index: felt252,
        router: felt252, start_time: u64, buy_fee_rate: felt252, sell_fee_rate: felt252,
        max_buy_amount: u256, delay_buy_time: felt252,
        initial_buy_amount: felt252);
    fn set_master_config(ref self: TState, fee_receiver: ContractAddress, fee_bps: felt252, ref_bps: felt252, pool_token: ContractAddress);
    fn set_pool_config(ref self: TState, initial_virtual_base_reserve: u256, initial_virtual_quote_reserve:u256, total_selling_base_amount: u256, max_listing_base_amount: u256, max_listing_quote_amount: u256, listing_fee: u256);
    fn buy(ref self: TState,  token: ContractAddress,
        referrer: ContractAddress,
        amount_in: u256,
        min_amount_out: u256 );
}
 
#[starknet::contract]
pub mod MemeCoin {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address,syscalls::deploy_syscall};
    use starknet::class_hash::ClassHash;
    use starknet::get_block_timestamp;
    #[storage]
    struct Storage {
        pool_info: Map<ContractAddress,PoolInfo>,
        master_config: MasterConfig,
        pool_config: PoolConfig,
    }
    
    // Define the PoolInfo struct
   #[derive(Drop, Serde, Copy, starknet::Store)]

    pub struct PoolInfo {
    id: felt252,
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
    buy_fee_rate: felt252,
    sell_fee_rate: felt252,
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
        fee_bps: felt252,
        ref_bps: felt252,
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
        pub buy_fee_rate: felt252,
        pub sell_fee_rate: felt252,
        pub max_buy_amount: u256,
        pub delay_buy_time: felt252,
        pub max_listing_quote_amount: u256,
        pub listing_fee: u256,
    }

    #[abi(embed_v0)]
    impl MemeCoinImpl of super::IMemeCoin<ContractState> {
        fn set_master_config(ref self: ContractState, fee_receiver: ContractAddress, fee_bps: felt252, ref_bps: felt252, pool_token: ContractAddress) {
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
            router: felt252, start_time: u64, buy_fee_rate: felt252, sell_fee_rate: felt252,
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
                id: 0,
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
        assert!( get_block_timestamp() < pool_token.start_time, "Not valid start time");
        assert!(amount_in <= pool_token.max_buy_amount, "Exceeded max buy");
        assert!(pool_token.listed_at == 0, "Invalid state");
        assert!(pool_token.virtual_base_reserve > pool_token.min_base_reserve);
        assert!(pool_token.virtual_quote_reserve < pool_token.min_quote_reserve + pool_token.max_listing_quote_amount + pool_token.listing_fee);
       
    }
}
}

