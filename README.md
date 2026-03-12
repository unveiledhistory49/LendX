# LendX Protocol

LendX is a production-grade decentralized lending and borrowing protocol built from the ground up for Ethereum Sepolia and Base Sepolia. Inspired by industry standards like Aave V3 and Compound V3, LendX provides a secure, efficient, and highly transparent platform for on-chain liquidity management.

## 1. Protocol Overview

LendX allows users to deposit supported ERC-20 assets as collateral to earn interest and borrow other assets. The protocol uses a purely mathematical interest accrual model (scaled balances) and a utilization-based interest rate curve to ensure solvency and optimal liquidity distribution.

**Key Features:**
- **Non-Custodial:** Users retain full control of their funds through a transparent смарт-контракт architecture.
- **Scaled Interests:** Interest accrues per-second via a global liquidity index, eliminating the need for expensive per-user updates.
- **Tiered Liquidations:** A dynamic bonus system incentivizes liquidators based on the severity of a position's health factor drop.
- **Flash Loans:** Integrated 0.09% fee flash loans for advanced DeFi arbitrage and rebalancing.

## 2. Architecture Diagram

```ascii
                      +-------------------+
                      |      USER         |
                      +---------+---------+
                                |
                                v
                      +-------------------+ (Routable entry point)
                      |   LendingPool     +-----------------------+
                      +---------+---------+                       |
                                |                                 |
           +--------------------+--------------------+            |
           |                    |                    |            v
+----------v----------+ +--------v----------+ +-------v-------+ +--+---+
|    SupplyLogic      | |    BorrowLogic     | | Liquidation  | |Oracle| 
+----------+----------+ +--------+----------+ |    Logic     | +--+---+
           |                    |             +-------+-------+    |
           |                    |                     |            |
           +----------+---------+----------+----------+            |
                      |                    |                       |
            +---------v---------+ +--------v---------+             |
            |      AToken       | |    DebtToken     |             |
            | (Interest Bearing)| | (Variable Debt)  |             |
            +---------+---------+ +--------+---------+             |
                      |                    |                       |
                      +----------+---------+                       |
                                 |                                 |
                       +---------v----------+                      |
                       | InterestRateStrat  | <--------------------+
                       +--------------------+
```

## 3. Supported Assets

| Asset | LTV | Liquidation Threshold | Liquidation Bonus |
|:---|:---:|:---:|:---:|
| **WETH** | 80% | 82.5% | 5% - 12% |
| **USDC** | 87% | 89.0% | 5% - 12% |
| **WBTC** | 70% | 75.0% | 5% - 12% |
| **LINK** | 65% | 70.0% | 5% - 12% |

## 4. Interest Rate Model

LendX implements a **two-slope utilization curve** modeled after the "hockey stick" curve to incentivize liquidity maintenance:

- **Below Optimal (80%):** A gentle slope (4% APR) is applied to keep borrowing costs low.
- **Above Optimal:** A steep slope (75% APR) is applied to rapidly attract depositors and discourage further borrowing, protecting protocol solvency.
- **Protocol Fee:** A 10% reserve factor is deducted from interest earned and redirected to the protocol treasury.

## 5. Liquidation Engine

The liquidation engine uses a **Tiered Bonus System** to prioritize the most at-risk positions:

| Health Factor (HF) | Liquidation Bonus |
|:---|:---:|
| **HF > 0.95** | 5% |
| **0.80 < HF ≤ 0.95** | 8% |
| **HF ≤ 0.80** | 12% |

*Note: A Max **50% Close Factor** is enforced to prevent total position wipeouts in single transactions and encourage multi-stage rebalancing.*

## 6. Security Considerations

### Protections
- **3-Check Oracle Safety:** Every price feed verification checks for (1) Positive price, (2) Staleness (< 1 hr), and (3) Round completeness.
- **Access Control:** Implements `Ownable2Step` for secure administrative transfers.
- **Invariant Testing:** 500+ runs of stateful fuzzing to verify protocol solvency and token supply consistency.
- **CEI Pattern:** Strict Checks-Effects-Interactions adherence on all state-changing functions.

### Known Limitations
- **Admin EOA:** The protocol owner is currently a single Externally Owned Account (not a DAO/Multisig).
- **Single-Asset Flash Loans:** Currently only supports one asset per flash loan call.
- **No E-Mode:** Correlated assets (e.g., LSTs) do not yet have specialized high-LTV modes.
- **Immutable Interest Parameters:** Interest rate curve parameters (slopes, optimal utilization) are immutable as per current deployment.
- **No Price Circuit Breaker:** The protocol relies on Chainlink safety checks but does not yet feature a secondary circuit breaker for extreme volatility.

## 7. Gas Optimization Report

Gas consumption is optimized via `unchecked` arithmetic, storage packing, and immutable constants.

| Operation | Gas Used (Optimized) |
|:---|:---|
| `supply()` | ~157,579 |
| `borrow()` | ~454,521 |
| `repay()` | ~395,643 |
| `liquidate()` | ~555,078 |

## 8. Deployment Addresses

### Ethereum Sepolia
- **LendingPool:** `0xCCe7623c811d97f4bef16C99e95419Cb0C96FB30`
- **PriceOracle:** `0x00472C0dA2a058D52cB577dC009890050D1F401B`
- **InterestRateStrategy:** `0xdD9Dc16177734f0CA0ac94AC7414377f7Ea37BCd`

### Base Sepolia
- **LendingPool:** `0xEfe0201a041636E4A9bD1AE3e5cD56985b3A9196`
- **PriceOracle:** `0xBbD100a3e9E3aC2d070C1beC6EA19caE06C714ff`
- **InterestRateStrategy:** `0xBE3f42aa0Ac12C2B7E6a91a0dD5EeFde39581476`

## 9. Running Tests

LendX uses Foundry for all testing and development.

```bash
# Run full test suite
forge test

# Run with gas report
forge test --gas-report

# Run specific integration tests
forge test --match-path test/integration/*.t.sol -vvv

# Run invariant tests
forge test --match-path test/invariant/*.t.sol

# Generate coverage report
forge coverage
```

## 10. Roadmap

- [ ] **E-Mode (Efficiency Mode):** Specialized LTV for correlated assets (e.g., sDAI/USDC).
- [ ] **Governance Transition:** Migrating from EOA to a Timelock + Governor contract.
- [ ] **Multi-Asset Flash Loans:** Allowing users to flash borrow multiple assets in one call.
- [ ] **Price Circuit Breaker:** Adding protection against extreme oracle volatility.
