#[starknet::interface]
pub trait ILibAthene<T> {
    fn get_amount_out(ref self: T, amount_in: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> Uint256;
    fn get_amount_in(ref self: T, amount_out: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> Uint256;
    fn get_pool_token_balance(ref self: T, token: felt) -> Uint256;
    fn get_reserves(ref self: T, pair: felt, currency: felt) -> (Uint256, Uint256);
    fn safe_approve(ref self: T, token: felt, spender: felt, amount: Uint256);
    fn safe_transfer(ref self: T, token: felt, to: felt, amount: Uint256);
    fn safe_transfer_from(ref self: T, token: felt, from: felt, to: felt, amount: Uint256);
    fn safe_deposit_and_transfer(ref self: T, weth: felt, to: felt, amount: Uint256);
    fn burn(ref self: T, token: felt, amount: Uint256);
    fn calculate_rate(ref self: T, base_amount: Uint256, quote_amount: Uint256) -> Uint256;
    fn convert_currency_to_token(ref self: T, amount: Uint256, rate: Uint256) -> Uint256;
    fn convert_token_to_currency(ref self: T, amount: Uint256, rate: Uint256) -> Uint256;
}

// contract A
#[starknet::contract]
pub mod LibAthene {
    #[storage]
    struct Storage {
        master_config_admin: felt,
    }

    #[abi(embed_v0)]
    impl ILibAtheneImpl of super::ILibAthene<ContractState> {

        fn get_amount_out(ref self: ContractState, amount_in: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> Uint256 {
            assert(amount_in.low > 0, 'Athene: INSUFFICIENT_INPUT_AMOUNT');
            assert(reserve_in.low > 0 && reserve_out.low > 0, 'Athene: INSUFFICIENT_LIQUIDITY');
            uint256_div(uint256_mul(amount_in, reserve_out), uint256_add(reserve_in, amount_in))
        }

        fn get_amount_in(ref self: ContractState, amount_out: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> Uint256 {
            assert(amount_out.low > 0, 'Athene: INSUFFICIENT_OUTPUT_AMOUNT');
            assert(reserve_in.low > 0 && reserve_out.low > 0, 'Athene: INSUFFICIENT_LIQUIDITY');
            uint256_add(uint256_div(uint256_mul(reserve_in, amount_out), uint256_sub(reserve_out, amount_out)), Uint256(1, 0))
        }

        fn get_pool_token_balance(ref self: ContractState, token: felt) -> Uint256 {
            IERC20(token).balanceOf(address(this))
        }

        fn get_reserves(ref self: ContractState, pair: felt, currency: felt) -> (Uint256, Uint256) {
            let (reserve0, reserve1, _) = IUniswapV2Pair(pair).getReserves();
            if currency == IUniswapV2Pair(pair).token0() {
                (reserve0, reserve1)
            } else {
                (reserve1, reserve0)
            }
        }

        fn safe_approve(ref self: ContractState, token: felt, spender: felt, amount: Uint256) {
            IERC20(token).approve(spender, Uint256(0, 0));
            IERC20(token).approve(spender, amount);
        }

        fn safe_transfer(ref self: ContractState, token: felt, to: felt, amount: Uint256) {
            IERC20(token).transfer(to, amount);
        }

        fn safe_transfer_from(ref self: ContractState, token: felt, from: felt, to: felt, amount: Uint256) {
            IERC20(token).transferFrom(from, to, amount);
        }

        fn safe_deposit_and_transfer(ref self: ContractState, weth: felt, to: felt, amount: Uint256) {
            IWETH(weth).deposit{ value: amount.low }();
            self.safe_transfer(weth, to, amount);
        }

        fn burn(ref self: ContractState, token: felt, amount: Uint256) {
            IERC20(token).transfer(address(0xdead), amount);
        }

        fn calculate_rate(ref self: ContractState, base_amount: Uint256, quote_amount: Uint256) -> Uint256 {
            uint256_div(uint256_mul(base_amount, Uint256(1e18, 0)), quote_amount)
        }

        fn convert_currency_to_token(ref self: ContractState, amount: Uint256, rate: Uint256) -> Uint256 {
            uint256_div(uint256_mul(amount, rate), Uint256(1e18, 0))
        }

        fn convert_token_to_currency(ref self: ContractState, amount: Uint256, rate: Uint256) -> Uint256 {
            uint256_div(uint256_mul(amount, Uint256(1e18, 0)), rate)
        }
    }
}

// contract B to make library call to the class of contract A
#[starknet::contract]
pub mod LibAtheneLibraryCall {
    use super::{ILibAtheneDispatcherTrait, ILibAtheneLibraryDispatcher};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        value: u32,
        lib_class_hash: starknet::ClassHash,
    }

    #[abi(embed_v0)]
    impl LibAthene of super::ILibAthene<ContractState> {
        fn set_admin(ref self: ContractState, new_admin: felt) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.set_admin(new_admin);
        }

        fn get_amount_out(ref self: ContractState, amount_in: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> Uint256 {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.get_amount_out(amount_in, reserve_in, reserve_out)
        }

        fn get_amount_in(ref self: ContractState, amount_out: Uint256, reserve_in: Uint256, reserve_out: Uint256) -> Uint256 {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.get_amount_in(amount_out, reserve_in, reserve_out)
        }

        fn get_pool_token_balance(ref self: ContractState, token: felt) -> Uint256 {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.get_pool_token_balance(token)
        }

        fn get_reserves(ref self: ContractState, pair: felt, currency: felt) -> (Uint256, Uint256) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.get_reserves(pair, currency)
        }

        fn safe_approve(ref self: ContractState, token: felt, spender: felt, amount: Uint256) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.safe_approve(token, spender, amount);
        }

        fn safe_transfer(ref self: ContractState, token: felt, to: felt, amount: Uint256) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.safe_transfer(token, to, amount);
        }

        fn safe_transfer_from(ref self: ContractState, token: felt, from: felt, to: felt, amount: Uint256) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.safe_transfer_from(token, from, to, amount);
        }

        fn safe_deposit_and_transfer(ref self: ContractState, weth: felt, to: felt, amount: Uint256) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.safe_deposit_and_transfer(weth, to, amount);
        }

        fn burn(ref self: ContractState, token: felt, amount: Uint256) {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.burn(token, amount);
        }

        fn calculate_rate(ref self: ContractState, base_amount: Uint256, quote_amount: Uint256) -> Uint256 {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.calculate_rate(base_amount, quote_amount)
        }

        fn convert_currency_to_token(ref self: ContractState, amount: Uint256, rate: Uint256) -> Uint256 {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.convert_currency_to_token(amount, rate)
        }

        fn convert_token_to_currency(ref self: ContractState, amount: Uint256, rate: Uint256) -> Uint256 {
            ILibAtheneLibraryDispatcher { class_hash: self.lib_class_hash.read() }.convert_token_to_currency(amount, rate)
        }
    }
}