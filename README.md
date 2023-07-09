# Defi-Dolly
> AppWorks Final Project

> LSD（Liquid Staking Derivatives，流動性質押衍生品）

## TL;DR
### 功能
- Stake ETH or stETH (build tenfold leverage)
- Unstake (to claim reward)
### 涉及協議
- Lido
- Balancer
- Compound V3
- Uniswap V3

## Description
### Pain Point
  一般用戶要透過循環借貸，擴大 Staking 的收益，會面臨三個門檻：
  #### 流程繁雜：要在各個協議之間串來串去
  ex. `在 Lido 質押 ETH、得到 wstETH` → `在 Compound 抵押 wstETH、得到 ETH` → (repeat…)
  #### gas fee 高
  ex. Compound 上，wstETH 的 collateral factor 是 90%
  若用戶自行手動操作，也要交易將近 30 次，才能將帳面資產擴大到接近理想槓桿目標
  
  (以下為：操作上述流程 30 次後，加總所有帳面資產 & 帳面借貸(是一個無窮等比級數和))

  |  | 資產 | 債務 |
  | --- | --- | --- |
  | 理想槓桿目標 | 10 | 9 |
  | 交易30次後 | 9.576088417 |  8.618479576 |
    
  #### 無法達到理想槓桿目標
  用上述方案，永遠無法實現理想槓桿目標，只能無窮逼近，等於浪費槓桿空間

### Gaol
- 建立一個平台，協助用戶用最低成本擴增帳面資產，實現理想槓桿目標
- 用戶質押 ETH or stETH 到平台，平台可以將其放大到數倍的帳面資產，以獲取更多質押獎勵。
  - 例如：`UserAsset` = 1 ETH
  - 目標：放大帳面資產 = `UserAsset1 * {1 + [CF / (1 - CF)]}`
      
      = 1 * 1 + ( 90% / 10% ) = 10 ETH

### Solution
  - Lido + FlashLoan + Compound

(以下本專案，稱 Hub)

#### Stake Flow
```mermaid
sequenceDiagram
    title Token Flow
    User->>+Hub: 1 ETH
    Note right of User: stake
    Balancer ->>+Hub: 9 ETH
      Hub ->>+Lido: 10 ETH
        Note right of Lido: draw interest
        Lido ->> -Hub: 8.9 wstETH (= 10 ETH)
        Hub ->> +Compound: wst8.9 ETH (= 10 ETH)
        Compound ->> -Hub: 9 ETH
        Hub ->> -Balancer: 9 ETH
        Hub ->> -User: wstETH(= 1 ETH)
        Note right of User: unstake
```
#### Unstake Flow
```mermaid
sequenceDiagram
	autonumber
		title Unstake Flow
	    User->>+Hub: 1 ETH
			Note right of User: stake
				Note over Hub: (Stake Flow)
				Note over Hub: 2 days ago
				Note over Hub: When user want unstake
				UniswapV3 ->> +Hub: 9.00164 wETH
						Hub ->> +Compound: 9.00164 wETH
						Compound ->> -Hub: 8.9008 wstETH					 
						Hub ->> -UniswapV3: 8.9008 wstETH
				Hub ->> Vault: 1.7583 stETH
				Note right of Hub: hub income					
			Hub ->> -User: 1.0027 stETH
			Note right of User: unstake
```

## Framework
- Proxy Contract: `Transparent`
- Imple Contrsct: `DefiDolly`

```mermaid
graph LR
  `A(ERC1967Proxy)
  A(TransparentUpgradeableProxy)
	B(Transparent)
	C(Ownable)
	D(IUniswapV3SwapCallback)
	E(DefiDolly)

	`A -- extends --> A
	A -- extends --> B
  C -- extends --> E
  D -- extends --> E
  B -- proxy --> E

```
## Development
init project

```tsx
git clone https://github.com/chaoting1995/defi-dolly.git
forge install
forge build
```
(TODO)

Include step-by-step instructions on how to set up and run the project.
.env.example
command example
If this project includes BE or FE, provide instructions for those as well.
## Testing
(TODO)

Explain how to run the tests.
[Nice to have] 80% or more coverage.
## Usage
(TODO)

Explain how to use the project and provide examples or code snippets to demonstrate its usage.