# GreenAfrica

## Hedera Certification

https://drive.google.com/file/d/1J5dpu8Mr0HWa4Uu2BkdkySVCzppRWVx4/view

## Pitch Deck

https://drive.google.com/file/d/1A5GV2dYkhUOWdbIoe0DIInnNxrAwEQ_r/view

**Track:** DLT for Operations  
**Sub-track**: 4, Sustainability & Impact Tech

GreenAfrica turns reverse vending machines deployed across African cities into digitally verifiable recycling stations, pairing real-world bottle recovery with instant, tokenized rewards backed by Hedera's low-cost, high-trust infrastructure.

## Vision & Impact

GreenAfrica's vision is to unlock a circular economy where every PET bottle keeps residual value and local recyclers earn reliable income without friction. We couple rugged reverse vending machines with a Hedera-backed loyalty layer so municipalities, FMCGs, and telecoms can co-fund incentives while seeing tamper-proof performance data.

- Reduce plastic leakage by rewarding deposit behavior exactly where waste is generated (bus parks, markets, campuses).
- Provide micro-earnings denominated as Green Points that convert into airtime/data bundles, smoothing household cash flow.
- Deliver audit-ready climate impact evidence so grants and ESG budgets translate into transparent, measurable outcomes.

## Monorepo Overview

| Folder     | Role in platform                                                                                  | Primary stack                         | Notable outputs                                                        |
| ---------- | ------------------------------------------------------------------------------------------------- | ------------------------------------- | ---------------------------------------------------------------------- |
| `contract` | Solidity smart contracts for RVM registry, deposits, referrals, and redemptions                   | Hardhat, Solidity 0.8                 | GreenAfrica.sol bytecode, contract ABIs, deployment scripts            |
| `rvm_api`  | Edge service that runs on the vending machine, detects bottles, and orchestrates reward issuance  | FastAPI, OpenCV, WebSockets           | Computer-vision event stream, QR code payloads, operator dashboard API |
| `rvm`      | Technician-facing mobile interface for provisioning RVMs and supervising sessions                 | Expo Router, React Native, TypeScript | Device onboarding flows, maintenance tools                             |
| `webapp`   | Consumer web experience for recyclers to view their impact, redeem rewards, and onboard referrals | Next.js 15, Tailwind, Firebase        | Responsive dashboard, reward flows, analytics                          |
| `website`  | Public marketing site — home, how it works, brands, partners, technology, about, contact          | Astro, Tailwind CSS v4                | Static site in `website/dist`                                          |

### Operational Flow

![Archtecture Diagram](/achitecture-diagram.png)
`GreenAfrica Archtecture Diagram`

1. The vending machine runs the `rvm_api`, which watches the region of interest on camera and emits bottle acceptance events with QR codes and session metadata.
2. Accepted events trigger on-board logic that mints Green Points and calls the Hedera smart contract via secure operator keys, anchoring deposit details (RVM, recycler, location, media hash).
3. A hashed summary of each deposit is also published to a Hedera Consensus Service topic for immutable compliance trails and third-party verification.
4. The Next.js webapp consumes both the contract state (Green Points balance, lifetime PET count) and the consensus topic feed via Mirror Node, presenting live dashboards to recyclers and sponsors.
5. Referral payouts and airtime/data redemptions are executed as atomic contract transactions, with fulfillment receipts returned to Firebase for messaging and CRM automation.

### Key On-Chain Records

- RVM registry with coordinates and activation status for every deployed machine.
- Recycler profiles keyed by hashed identifiers, including referral codes and lifetime statistics.
- Deposit, referral, and redemption events emitted with rich indexing to support Mirror Node analytics and ESG reporting.

### Analytics & Monitoring

- Mirror Node queries surface bottle counts, points issued, and redemption latency per location.
- Firebase/Firestore stores user-facing state and acts as notification bus.
- Telemetry from `rvm_api` (QR scans, event latency) is surfaced to judges through Grafana-ready JSON endpoints.

## Hedera Integration Summary

### Hedera Smart Contract Service

We deployed the GreenAfrica RVM Registry contract (`0.0.6779400`) on the Hedera Smart Contract Service to enforce business logic around deposits, referrals, and redemptions in a single atomic call. Contract execution gives us deterministic settlement with ABFT finality, and the predictable ~$0.0003 `ContractExecuteTransaction` fee lets us log tens of thousands of daily deposits without eroding razor-thin recycling margins.

### Hedera Token Service

Green Points (`0.0.6919030`) is an HTS token that represents off-chain value such as airtime or data bundles. The Token Service supplies treasury controls, automatic KYC-less associations, and batched transfers so we can mint reward inventory once (`TokenCreateTransaction` + `TokenMintTransaction`) and stream micro-awards at ~$0.0001 per `TransferTransaction`, making incentive distribution viable across low-income communities.

### Hedera Consensus Service

We broadcast hashed deposit receipts to a dedicated HCS topic so sponsors and regulators can independently verify activity through Mirror Node. Submitting each payload with `TopicMessageSubmitTransaction` costs roughly $0.0001, yet gives us immutable sequencing and a tamper-evident timeline of machine uptime, enabling SLA enforcement and trust for grant-funded deployments.

## Hedera Transaction Types

- `TokenCreateTransaction` — one-off creation of the Green Points HTS token treasury.
- `TokenMintTransaction` — periodic top-ups of the reward pool when sponsorship funds refresh.
- `TransferTransaction` — distribution of Green Points to recyclers and referral accounts.
- `ContractExecuteTransaction` — invoking `recordDeposit`, `redeemPoints`, and admin functions on the GreenAfrica contract.
- `ContractCallQuery` — reading user balances and machine state for dashboards without consuming gas.
- `TopicMessageSubmitTransaction` — anchoring hashed deposit receipts and operational alerts on HCS for third-party monitoring.

## Economic Justification

- Hedera's fixed micro-fees keep the per-bottle blockchain cost under $0.0005, preserving more than 99% of sponsorship budgets for user rewards instead of infrastructure.
- Finality in ~5 seconds with ABFT security allows airtime and data rewards to settle instantly, increasing user trust and daily active recycling sessions.
- High throughput and native tokenization eliminate the need for custodial intermediaries, reducing compliance overhead and simplifying expansion into new African markets.

## Setup Instructions (Web App)

- **Clone this monorepo:** then `cd greenafrica`.
- **Install web dependencies:** `cd webapp && npm install`.
- **Create environment file:** `cp .env.example .env.local`.
- **Configure Firebase:** set all `NEXT_PUBLIC_FIREBASE_*`, `FIREBASE_PRIVATE_KEY`, and `FIREBASE_CLIENT_EMAIL` values with your Firebase project credentials.
- **Configure Hedera access:** set `HEDERA_NETWORK=testnet`, point `HEDERA_RPC_URL` to a testnet endpoint (e.g. `https://testnet.hashio.io/api`), and provide operator `HEDERA_OPERATOR_ID`/`HEDERA_OPERATOR_KEY`.
- **Link project contracts:** ensure `GREEN_AFRICA_CONTRACT_ID` and `GREENPOINTS_TOKEN_ID` reflect the desired testnet deployments.
- **Run the dev server:** `npm run dev`, then open `http://localhost:3000` to interact with the Hedera testnet-backed dashboard.

## Hedera Testnet Contracts

- GreenAfrica RVM Contract ID: `0.0.6779400`
- GreenPoints HTS Token ID: `0.0.6919030`

## Judge & Mentor Quick Links

- Consumer UX: `webapp/src/app`
- Smart Contract Logic: `contract/contracts/GreenAfrica.sol`
- Machine Vision Pipeline: `rvm_api/app`
- Field Ops Mobile App: `rvm/app`

## Roadmap Highlights

- Deploy 5 pilot machines across Lagos transit hubs with sponsor-backed reward pools.
- Launch SMS fallback for low-end devices, mirroring Hedera balances via Firebase functions.
- Expand HCS analytics with carbon-equivalent calculations for ESG-grade reporting.
