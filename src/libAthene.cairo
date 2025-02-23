pub mod token;
#[starknet::interface]
pub trait ILibAthene<T> {
    fn get_amount_out(ref self: T, amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256;
    fn get_amount_in(ref self: T, amount_out: u256, reserve_in: u256, reserve_out: u256) -> u256;
    fn calculateRate(ref self: T,base_amount: u256, quote_amount: u256) -> u256;
    fn convertCurrencyToToken(ref self: T, amount: u256, rate: u256) -> u256;
    fn convertTokenToCurrency(ref self: T, amount: u256, rate: u256) -> u256;
    fn getPoolTokenBalance(ref self: T, pool_address: ContractAddress) -> u256;
    
}
mod Errors {
        pub const WRONG_INPUT_AMOUNT: felt252 = 'Input amount must be > 0';
        pub const WRONG_OUTPUT_AMOUNT: felt252 = 'Output amount must be > 0';

    pub const INSUFFICIENT_LIQUIDITY: felt252 = 'INSUFFICIENT_LIQUIDITY';
}

// contract A
#[starknet::contract]
pub mod LibAthene {
    use starknet::{get_contract_address, ContractAddress};
    use token::IERC20Dispatcher;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl ILibAtheneImpl of super::ILibAthene<ContractState> {

        fn get_amount_out(ref self: ContractState, amount_in: u256, reserve_in: u256, reserve_out: u256) -> u256 {
            assert(amount_in > 0,super::Errors::WRONG_INPUT_AMOUNT);
            assert(reserve_in > 0 && reserve_out > 0, super::Errors::INSUFFICIENT_LIQUIDITY);
            let amount_out = (amount_in * reserve_out) / (reserve_in + amount_in);
            return amount_out;
        }

        fn get_amount_in(ref self: ContractState, amount_out: u256, reserve_in: u256, reserve_out: u256) -> u256 {
            assert(amount_out > 0, super::Errors::WRONG_OUTPUT_AMOUNT);
            assert(reserve_in > 0 && reserve_out > 0, super::Errors::INSUFFICIENT_LIQUIDITY);
            let amount_in = ((amount_out * reserve_in) / (reserve_out - amount_out)) +1;
            return amount_in;
        }

        fn calculateRate(ref self: ContractState,base_amount: u256, quote_amount: u256) -> u256 {
            let one_e18 = 1000000000000000000;
            let rate = (quote_amount * one_e18) / base_amount;
            return rate;
        }

        fn convertCurrencyToToken(ref self: ContractState, amount: u256, rate: u256) -> u256 {
            let token_amount = (amount * rate) / 1000000000000000000;
            return token_amount;
        }

        fn convertTokenToCurrency(ref self: ContractState, amount: u256, rate: u256) -> u256 {
            let currency_amount = (amount * 1000000000000000000) / rate;
            return currency_amount;
        }

        fn getPoolTokenBalance(ref self: ContractState, pool_address: ContractAddress) -> u256 {
            let balance = IERC20Dispatcher{ contract_address: pool_address }.balance_of(get_contract_address());
            return balance;
        }
    }
}


