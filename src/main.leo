import credits.aleo;
import token_registry.aleo;

// The 'compliant_token' program.
program kub_compliant_token.aleo {
  const COMPLAINT_TOKEN_ID: field = 71619063553950105623552field;
  const ADMIN_ADDRESS: address = aleo1etcfylxvf5waf3crajnjn440gqm0pyder84sfqxgqtqyy4pcc58s0y8anf;
  const MAX_SUPPLY: u128 = 1_000_000_000_000_000u128;
  const BLOCKS_IN_A_DAY: u32 = 28_800u32;
  const MAX_SPEND_PER_DAY: u128 = 10_000_000_000u128;
  const MAX_U32: u32 = 4294967295u32;
  const FEE_PERCENTAGE: u128 = 2u128; // 2% transaction fee

  record SpendLimit {
    owner: address,
    amount_spent: u128,
    epoch_spent: u32
  }

  mapping has_minted: u8 => bool;
  mapping has_spend_limit: field => bool;

  async transition transfer_private(
    input_token: token_registry.aleo/Token,
    spend_limit: SpendLimit,
    amount: u128,
    recipient: address,
    public epoch: u32
  ) -> (SpendLimit, token_registry.aleo/Token, token_registry.aleo/Token, token_registry.aleo/Token, token_registry.aleo/Token, Future) {
let updated_amount_spent: u128 = amount;

if spend_limit.epoch_spent >= epoch {
    updated_amount_spent += spend_limit.amount_spent;
}
    
    assert(updated_amount_spent <= MAX_SPEND_PER_DAY);

    let fee: u128 = (amount * FEE_PERCENTAGE) / 100u128;
    let net_amount: u128 = amount - fee;
    
    let updated_spend_limit: SpendLimit = SpendLimit {
      owner: spend_limit.owner,
      amount_spent: updated_amount_spent,
      epoch_spent: epoch
    };
    
    let prehook_output: (token_registry.aleo/Token, token_registry.aleo/Token, Future) = token_registry.aleo/prehook_private(
      input_token,
      amount,
      MAX_U32
    );
    
    let transfer_output: (token_registry.aleo/Token, token_registry.aleo/Token, Future) = token_registry.aleo/transfer_private(
      recipient,
      net_amount,
      prehook_output.1
    );
    
    let fee_transfer_output: (token_registry.aleo/Token, token_registry.aleo/Token, Future) = token_registry.aleo/transfer_private(
      ADMIN_ADDRESS,
      fee,
      prehook_output.1
    );
    
    return (
      updated_spend_limit,
      prehook_output.0,
      transfer_output.0,
      transfer_output.1,
      fee_transfer_output.1,
      finalize_transfer_private(prehook_output.2, transfer_output.2, fee_transfer_output.2, epoch)
    );
  }

  async function finalize_transfer_private(
    f0: Future,
    f1: Future,
    f2: Future,
    epoch: u32
  ) {
    f0.await();
    f1.await();
    f2.await();
    let current_epoch: u32 = block.height % BLOCKS_IN_A_DAY;
    assert_eq(epoch, current_epoch);
  }

  async transition burn(
    input_token: token_registry.aleo/Token,
    amount: u128
  ) -> (token_registry.aleo/Token, Future) {
    let prehook_output: (token_registry.aleo/Token, token_registry.aleo/Token, Future) = token_registry.aleo/prehook_private(
      input_token,
      amount,
      MAX_U32
    );
    
    let burn_output: (token_registry.aleo/Token, Future) = token_registry.aleo/burn(
      prehook_output.1,
      amount
    );
    
    return (
      prehook_output.0,
      finalize_burn(prehook_output.2, burn_output.1)
    );
  }

  async function finalize_burn(f0: Future, f1: Future) {
    f0.await();
    f1.await();
  }
}
