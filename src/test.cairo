#[starknet::interface]
pub trait IMemeCoin<TState> {
    fn create_pool(ref self: TState,
        name: felt252, symbol: felt252, pool_details: felt252, config_index: felt252,
        router: felt252, start_time: felt252, buy_fee_rate: felt252, sell_fee_rate: felt252,
        max_buy_amount: felt252, delay_buy_time: felt252,
        initial_buy_amount: felt252) -> felt252;
}
 
#[starknet::contract]
pub mod MeMeCoin {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::storage::{Map, StorageMapReadAccess, StorageMapWriteAccess};
    use starknet::{ContractAddress, get_caller_address, get_contract_address,syscalls::deploy_syscall};
    use starknet::class_hash::ClassHash;
    #[storage]
    struct Storage {
        pool_info: Map<ContractAddress,PoolInfo>,
    }
    
    // Define the PoolInfo struct
   #[derive(Drop, Serde, Copy, starknet::Store)]

    pub struct PoolInfo {
    id: felt252,
    owner: felt252,
    router: felt252,
    pool_details: felt252,
    state: felt252,
    virtual_base_reserve: felt252,
    virtual_quote_reserve: felt252,
    min_base_reserve: felt252,
    min_quote_reserve: felt252,
    max_listing_base_amount: felt252,
    max_listing_quote_amount: felt252,
    default_listing_rate: felt252,
    listing_fee: felt252,
    start_time: felt252,
    listed_at: felt252,
    buy_fee_rate: felt252,
    sell_fee_rate: felt252,
    max_buy_amount: felt252,
    delay_buy_time: felt252,
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
        pub user: felt252,
        pub base_reserve: felt252,
        pub quote_reserve: felt252,
        pub timestamp: felt252,
        pub pool_details: felt252,
        pub start_time: felt252,
        pub buy_fee_rate: felt252,
        pub sell_fee_rate: felt252,
        pub max_buy_amount: felt252,
        pub delay_buy_time: felt252,
        pub max_listing_quote_amount: felt252,
        pub listing_fee: felt252,
    }

    #[abi(embed_v0)]
    impl MemeCoinImpl of super::IMemeCoin<ContractState> {
        fn create_pool(
            ref self: ContractState,
            name: felt252, symbol: felt252, pool_details: felt252, config_index: felt252,
            router: felt252, start_time: felt252, buy_fee_rate: felt252, sell_fee_rate: felt252,
            max_buy_amount: felt252, delay_buy_time: felt252,
            initial_buy_amount: felt252
        ) -> felt252 {
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
                owner: 0,
                router,
                pool_details,
                state: 0,
                virtual_base_reserve: 0,
                virtual_quote_reserve: 0,
                min_base_reserve: 0,
                min_quote_reserve: 0,
                max_listing_base_amount: 0,
                max_listing_quote_amount: 0,
                default_listing_rate: 0,
                listing_fee: 0,
                start_time,
                listed_at: 0,
                buy_fee_rate,
                sell_fee_rate,
                max_buy_amount,
                delay_buy_time,
            });

            self.emit(TokenCreated {
                token: 0,
                user: 0,
                base_reserve: 0,
                quote_reserve: 0,
                timestamp: 0,
                pool_details,
                start_time,
                buy_fee_rate,
                sell_fee_rate,
                max_buy_amount,
                delay_buy_time,
                max_listing_quote_amount: 0,
                listing_fee: 0,
            });
            return 0;
        }
    }
}
