export const LENDING_POOL_ABI = [
  {"type":"constructor","inputs":[{"name":"oracle","type":"address","internalType":"address"},{"name":"interestRateStrategy","type":"address","internalType":"address"}],"stateMutability":"nonpayable"},
  {"type":"function","name":"BORROW_LOGIC","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"LIQUIDATION_LOGIC","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"SUPPLY_LOGIC","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"VALIDATION_LOGIC","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"addReserve","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"aTokenAddress","type":"address","internalType":"address"},{"name":"debtTokenAddress","type":"address","internalType":"address"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"borrow","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"amount","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"flashLoan","inputs":[{"name":"receiverAddress","type":"address","internalType":"address"},{"name":"assets","type":"address[]","internalType":"address[]"},{"name":"amounts","type":"uint256[]","internalType":"uint256[]"},{"name":"params","type":"bytes","internalType":"bytes"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"getAddressesProvider","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"getReserveData","inputs":[{"name":"asset","type":"address","internalType":"address"}],"outputs":[{"name":"configuration","type":"uint256","internalType":"uint256"},{"name":"liquidityIndex","type":"uint128","internalType":"uint128"},{"name":"variableBorrowIndex","type":"uint128","internalType":"uint128"},{"name":"currentLiquidityRate","type":"uint128","internalType":"uint128"},{"name":"currentVariableBorrowRate","type":"uint128","internalType":"uint128"},{"name":"lastUpdateTimestamp","type":"uint40","internalType":"uint40"},{"name":"aTokenAddress","type":"address","internalType":"address"},{"name":"debtTokenAddress","type":"address","internalType":"address"},{"name":"id","type":"uint8","internalType":"uint8"}],"stateMutability":"view"},
  {"type":"function","name":"getReserveNormalizedIncome","inputs":[{"name":"asset","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"getReserveNormalizedVariableDebt","inputs":[{"name":"asset","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"getReservesList","inputs":[],"outputs":[{"name":"","type":"address[]","internalType":"address[]"}],"stateMutability":"view"},
  {"type":"function","name":"getUserAccountData","inputs":[{"name":"user","type":"address","internalType":"address"}],"outputs":[{"name":"totalCollateralBase","type":"uint256","internalType":"uint256"},{"name":"totalDebtBase","type":"uint256","internalType":"uint256"},{"name":"availableBorrowsBase","type":"uint256","internalType":"uint256"},{"name":"currentLiquidationThreshold","type":"uint256","internalType":"uint256"},{"name":"ltv","type":"uint256","internalType":"uint256"},{"name":"healthFactor","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"getUserConfiguration","inputs":[{"name":"user","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"liquidationCall","inputs":[{"name":"collateralAsset","type":"address","internalType":"address"},{"name":"debtAsset","type":"address","internalType":"address"},{"name":"user","type":"address","internalType":"address"},{"name":"debtToCover","type":"uint256","internalType":"uint256"},{"name":"receiveAToken","type":"bool","internalType":"bool"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"owner","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"pause","inputs":[],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"paused","inputs":[],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"view"},
  {"type":"function","name":"renounceOwnership","inputs":[],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"repay","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"amount","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"nonpayable"},
  {"type":"function","name":"setReserveConfiguration","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"ltv","type":"uint256","internalType":"uint256"},{"name":"threshold","type":"uint256","internalType":"uint256"},{"name":"bonus","type":"uint256","internalType":"uint256"},{"name":"active","type":"bool","internalType":"bool"},{"name":"frozen","type":"bool","internalType":"bool"},{"name":"borrowingEnabled","type":"bool","internalType":"bool"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"supply","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"amount","type":"uint256","internalType":"uint256"},{"name":"onBehalfOf","type":"address","internalType":"address"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"transferOwnership","inputs":[{"name":"newOwner","type":"address","internalType":"address"}],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"unpause","inputs":[],"outputs":[],"stateMutability":"nonpayable"},
  {"type":"function","name":"withdraw","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"amount","type":"uint256","internalType":"uint256"},{"name":"to","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"nonpayable"}
] as const;

export const PRICE_ORACLE_ABI = [
  {"type":"function","name":"getAssetPrice","inputs":[{"name":"asset","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"setAssetPrice","inputs":[{"name":"asset","type":"address","internalType":"address"},{"name":"price","type":"uint256","internalType":"uint256"}],"outputs":[],"stateMutability":"nonpayable"}
] as const;

export const ATOKEN_ABI = [
  {"type":"function","name":"UNDERLYING_ASSET_ADDRESS","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"balanceOf","inputs":[{"name":"user","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"balanceOfWithIndex","inputs":[{"name":"user","type":"address","internalType":"address"},{"name":"index","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"decimals","inputs":[],"outputs":[{"name":"","type":"uint8","internalType":"uint8"}],"stateMutability":"view"},
  {"type":"function","name":"name","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},
  {"type":"function","name":"symbol","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},
  {"type":"function","name":"totalSupply","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"}
] as const;

export const DEBT_TOKEN_ABI = [
  {"type":"function","name":"UNDERLYING_ASSET_ADDRESS","inputs":[],"outputs":[{"name":"","type":"address","internalType":"address"}],"stateMutability":"view"},
  {"type":"function","name":"balanceOf","inputs":[{"name":"user","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"balanceOfWithIndex","inputs":[{"name":"user","type":"address","internalType":"address"},{"name":"index","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"decimals","inputs":[],"outputs":[{"name":"","type":"uint8","internalType":"uint8"}],"stateMutability":"view"},
  {"type":"function","name":"name","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},
  {"type":"function","name":"symbol","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},
  {"type":"function","name":"totalSupply","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"}
] as const;

export const ERC20_ABI = [
  {"type":"function","name":"allowance","inputs":[{"name":"owner","type":"address","internalType":"address"},{"name":"spender","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"approve","inputs":[{"name":"spender","type":"address","internalType":"address"},{"name":"value","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"nonpayable"},
  {"type":"function","name":"balanceOf","inputs":[{"name":"account","type":"address","internalType":"address"}],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"decimals","inputs":[],"outputs":[{"name":"","type":"uint8","internalType":"uint8"}],"stateMutability":"view"},
  {"type":"function","name":"name","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},
  {"type":"function","name":"symbol","inputs":[],"outputs":[{"name":"","type":"string","internalType":"string"}],"stateMutability":"view"},
  {"type":"function","name":"totalSupply","inputs":[],"outputs":[{"name":"","type":"uint256","internalType":"uint256"}],"stateMutability":"view"},
  {"type":"function","name":"transfer","inputs":[{"name":"to","type":"address","internalType":"address"},{"name":"value","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"nonpayable"},
  {"type":"function","name":"transferFrom","inputs":[{"name":"from","type":"address","internalType":"address"},{"name":"to","type":"address","internalType":"address"},{"name":"value","type":"uint256","internalType":"uint256"}],"outputs":[{"name":"","type":"bool","internalType":"bool"}],"stateMutability":"nonpayable"}
] as const;
