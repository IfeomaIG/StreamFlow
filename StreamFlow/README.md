# StreamFlow - Continuous Payment Streaming System

StreamFlow is a smart contract built on the Stacks blockchain that enables continuous, real-time payment streaming between users. It allows for automated, block-by-block value distribution without requiring manual intervention for each payment.

## Features

- **Continuous Payment Streaming**: Set up automated payments that flow continuously over time
- **Real-time Value Distribution**: Payments are distributed block-by-block based on predefined flow rates
- **Flexible Duration**: Create streams for any duration with customizable flow rates
- **Secure Fund Management**: Built-in escrow system with secure fund locking and release
- **Low Transaction Fees**: Configurable service fees (default 3%)
- **Stream Cancellation**: Both senders and receivers can cancel streams with automatic fund settlement

## Core Concepts

### Payment Streams
A payment stream is a continuous flow of STX tokens from a sender to a receiver over a specified period. Each stream has:
- **Flow Rate**: Amount of micro-STX per block
- **Duration**: Number of blocks the stream will run
- **Total Deposit**: Total amount locked for the entire stream duration

### Account Balances
Users maintain internal balances within the contract that are used to fund payment streams. This provides:
- Efficient fund management
- Reduced transaction costs
- Batch operations support

## Usage

### For Senders

1. **Deposit Funds**
   ```clarity
   (deposit-funds amount)
   ```
   Load your account with STX tokens to fund payment streams.

2. **Create a Stream**
   ```clarity
   (create-stream receiver flow-rate duration)
   ```
   - `receiver`: Principal address to receive the stream
   - `flow-rate`: Micro-STX per block
   - `duration`: Number of blocks for the stream

3. **Cancel a Stream**
   ```clarity
   (cancel-stream stream-id)
   ```
   Cancel an active stream and receive unstreamed funds back.

### For Receivers

1. **Claim Payments**
   ```clarity
   (claim-payment stream-id)
   ```
   Withdraw available payments from an active stream.

### For Both Users

1. **Withdraw Funds**
   ```clarity
   (withdraw-funds amount)
   ```
   Withdraw STX tokens from your internal account balance.

2. **Check Stream Details**
   ```clarity
   (get-stream-details stream-id)
   ```
   View complete information about a specific stream.

3. **Check Available Withdrawal**
   ```clarity
   (calculate-available-withdrawal stream-id)
   ```
   See how much can be withdrawn from a stream.

## Technical Specifications

### Constants
- **Service Fee**: 3% (300 basis points) - configurable by contract owner
- **Minimum Stream Amount**: 1000 micro-STX
- **Maximum Service Fee**: 20% (2000 basis points)

### Error Codes
- `u600`: Owner-only function called by non-owner
- `u601`: Stream not found
- `u602`: Insufficient balance
- `u603`: Invalid parameters
- `u604`: Stream inactive
- `u605`: Unauthorized access

### Data Structures

#### Payment Streams
```clarity
{
    sender: principal,
    receiver: principal,
    flow-rate: uint,
    total-deposit: uint,
    start-block: uint,
    end-block: uint,
    withdrawn-total: uint,
    stream-status: bool
}
```

#### Account Balances
```clarity
{
    account: principal,
    balance: uint
}
```

## Security Features

- **Access Control**: Only stream participants can cancel streams
- **Fund Safety**: Locked funds are secured in contract escrow
- **Automatic Settlement**: Proper fund distribution on stream cancellation
- **Parameter Validation**: Comprehensive input validation
- **Owner Controls**: Limited administrative functions with safety bounds

## Use Cases

- **Salary Payments**: Stream employee salaries block-by-block
- **Subscription Services**: Continuous payment for ongoing services
- **Vesting Schedules**: Token or payment vesting over time
- **Rental Payments**: Automated rent payments
- **Freelancer Payments**: Progressive payment for long-term projects

## Contract Owner Functions

The contract owner (deployer) can:
- Update service fee (max 20%)
- Update minimum stream amount
- Cannot access user funds or interfere with streams

## Getting Started

1. Deploy the StreamFlow contract to Stacks blockchain
2. Fund your account using `deposit-funds`
3. Create your first payment stream
4. Recipients can claim payments as they become available
