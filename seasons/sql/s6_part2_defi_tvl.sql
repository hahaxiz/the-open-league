with wallets_end as (
  select address, last_transaction_lt as tx_lt, jetton as  jetton_master, "owner", balance from jetton_wallets
),
jvault_pools as (
 select address as pool_address from nft_items ni where collection_address =upper('0:184b700ed8d685af9fb0975094f103220b1acfd0e117627f368aa9ee493f452a')
), jvault_pool_tvls as (
 select pool_address, 
  coalesce (sum( (select price_usd from prices.agg_prices ap where ap.base = jetton_master and price_time < 1730286000 order by price_time desc limit 1) * balance / 1e6), 0)
  +
  coalesce (sum( (select tvl_usd / total_supply from prices.dex_pool_history dph where pool = jetton_master and timestamp < 1730286000 order by timestamp desc limit 1) * balance), 0)
   as value_usd
   from wallets_end b
   join jvault_pools p on p.pool_address = b."owner"
   group by 1
), jvault_lp_tokens as (
   select jm.address as lp_master, pool_address from jetton_masters jm join jvault_pools p on p.pool_address =admin_address
), jvault_balances_before as (
 select ed.address, lp_master, balance from tol.jetton_wallets_s6_part2_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join jvault_lp_tokens on lp_master = b.jetton_master
), jvault_balances_after as (
 select ed.address, lp_master, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join jvault_lp_tokens on lp_master = b.jetton_master
), jvault_balances_delta as (
 select address, lp_master, coalesce(jvault_balances_after.balance, 0) - coalesce(jvault_balances_before.balance, 0) as balance_delta
 from jvault_balances_after left join jvault_balances_before using(address, lp_master) 
), jvault_total_supply as (
   select lp_master, sum(balance) as total_supply
   from wallets_end b
   join jvault_lp_tokens on lp_master = b.jetton_master
   group by 1
   having sum(balance) > 0
), jvault_impact as (
 select address, sum(value_usd * balance_delta / total_supply) as tvl_impact from jvault_balances_delta
 join jvault_total_supply using(lp_master)
 join jvault_lp_tokens using(lp_master)
 join jvault_pool_tvls using(pool_address)
 group by 1
), settleton_pools as (
  select address as pool_address from jetton_masters jm where 
  code_hash ='BfWQzLvuCKusWfxaQs48Xp+Nf+jUIBN8BVrU0li7qXI='
), settleton_pool_tvls as (
 select pool_address, 
  coalesce (sum( (select tvl_usd / total_supply from prices.dex_pool_history dph where pool = jetton_master and timestamp < 1730286000 order by timestamp desc limit 1) * balance), 0)
   as value_usd
   from wallets_end b
   join settleton_pools p on p.pool_address = b."owner"
   group by 1
), settleton_balances_before as (
 select ed.address, pool_address, balance from tol.jetton_wallets_s6_part2_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join settleton_pools on pool_address = b.jetton_master
), settleton_balances_after as (
 select ed.address, pool_address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join settleton_pools on pool_address = b.jetton_master
), settleton_balances_delta as (
 select address, pool_address, coalesce(settleton_balances_after.balance, 0) - coalesce(settleton_balances_before.balance, 0) as balance_delta
 from settleton_balances_after left join settleton_balances_before using(address, pool_address) 
), settleton_total_supply as (
   select pool_address, sum(balance) as total_supply
   from wallets_end b
   join settleton_pools on pool_address = b.jetton_master
   group by 1
   having sum(balance) > 0
), settleton_impact as (
 select address, sum(value_usd * balance_delta / total_supply) as tvl_impact from settleton_balances_delta
 join settleton_total_supply using(pool_address)
 join settleton_pool_tvls using(pool_address)
 group by 1
), daolama_tvl as (
select balance * (select price from prices.ton_price where price_ts < 1730286000 order by price_ts desc limit 1) / 1e9 as tvl_usd 
from account_states as2 where hash = (
select account_state_hash_after from transactions where account = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
and now < 1730286000
order by now desc limit 1)
), daolama_balances_before as (
 select ed.address, balance from tol.jetton_wallets_s6_part2_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
), daolama_balances_after as (
 select ed.address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
), daolama_balances_delta as (
 select address, coalesce(daolama_balances_after.balance, 0) - coalesce(daolama_balances_before.balance, 0) as balance_delta
 from daolama_balances_after left join daolama_balances_before using(address)
), daolama_total_supply as (
   select sum(balance) as total_supply
   from wallets_end b
   where b.jetton_master = upper('0:a4793bce49307006d3f4e97d815fb4c78ff7655faecf8606111ae29f8d6b41f4')
), daolama_impact as (
 select address, sum((select tvl_usd from daolama_tvl) * balance_delta / (select total_supply from daolama_total_supply)) as tvl_impact from daolama_balances_delta
 group by 1
), tonhedge_tvl as (
 select balance / 1e6 as tvl_usd from wallets_end
 where owner = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
 and jetton_master = '0:B113A994B5024A16719F69139328EB759596C38A25F59028B146FECDC3621DFE'
), tonhedge_balances_before as (
 select ed.address, balance from tol.jetton_wallets_s6_part2_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
), tonhedge_balances_after as (
 select ed.address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 where b.jetton_master = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
), tonhedge_balances_delta as (
 select address, coalesce(tonhedge_balances_after.balance, 0) - coalesce(tonhedge_balances_before.balance, 0) as balance_delta
 from tonhedge_balances_after left join tonhedge_balances_before using(address)
), tonhedge_total_supply as (
   select sum(balance) as total_supply
   from wallets_end b
   where b.jetton_master = upper('0:57668d751f8c14ab76b3583a61a1486557bd746beeebbd4b2a65418b3fdb5471')
), tonhedge_impact as (
 select address, sum((select tvl_usd from tonhedge_tvl) * balance_delta / (select total_supply from tonhedge_total_supply)) as tvl_impact 
 from tonhedge_balances_delta
 group by 1
), tonpools_operations as (
  select source as address, value / 1e9 * 
  (select price from prices.ton_price where price_ts < m.created_at order by price_ts desc limit 1) as value_usd
  from messages m where direction ='in' and destination =upper('0:3bcbd42488fe31b57fc184ea58e3181594b33b2cf718500e108411e115978be1')
  and created_at  >= 1728558000 and created_at < 1730286000 and opcode = 569292295

   union all

  select m_in.source as address, -1 * m_out.value  / 1e9 *
  (select price from prices.ton_price where price_ts < m_out.created_at order by price_ts desc limit 1) as value_usd
  from messages m_in
  join messages m_out on m_out.tx_hash  = m_in.tx_hash and m_out.direction  = 'out'
  join parsed.message_comments mc on mc.hash  = m_out.body_hash 
  where m_in.direction ='in' and m_in.destination =upper('0:3bcbd42488fe31b57fc184ea58e3181594b33b2cf718500e108411e115978be1')
  and m_in.created_at  >= 1728558000 and m_in.created_at < 1730286000 and m_in.opcode = 195467089
  and mc."comment" = 'Withdraw completed'
), tonpools_impact as (
 select address, sum(value_usd) as tvl_impact
 from tonpools_operations group by 1
), parraton_pools as (
  select address as pool_address from jetton_masters jm where 
  admin_address = '0:705A574E176A47C785CCE821E5C1DC551BA65F70E828913EFAEF6DFA648184E6'
), parraton_pool_tvls as (
 select pool_address, 
  coalesce (sum( (select tvl_usd / total_supply from prices.dex_pool_history dph where pool = jetton_master and timestamp < 1730286000 order by timestamp desc limit 1) * balance), 0)
   as value_usd
   from wallets_end b
   join parraton_pools p on p.pool_address = b."owner"
   group by 1
), parraton_balances_before as (
 select ed.address, pool_address, balance from tol.jetton_wallets_s6_part2_start b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join parraton_pools on pool_address = b.jetton_master
), parraton_balances_after as (
 select ed.address, pool_address, balance from wallets_end b
 join tol.enrollment_degen ed on ed.address = b."owner"
 join parraton_pools on pool_address = b.jetton_master
), parraton_balances_delta as (
 select address, pool_address, coalesce(parraton_balances_after.balance, 0) - coalesce(parraton_balances_before.balance, 0) as balance_delta
 from parraton_balances_after left join parraton_balances_before using(address, pool_address) 
), parraton_total_supply as (
   select pool_address, sum(balance) as total_supply
   from wallets_end b
   join parraton_pools on pool_address = b.jetton_master
   group by 1
  having sum(balance) > 0
), parraton_impact as (
 select address, sum(value_usd * balance_delta / total_supply) as tvl_impact from parraton_balances_delta
 join parraton_total_supply using(pool_address)
 join parraton_pool_tvls using(pool_address)
 group by 1
), tonstable_flow as (
  select 
  case when destination = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f') then source
  else destination end as address,
  case when source = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f') then -1 else 1 end * amount / 1e9 * 
  coalesce((select price from prices.core where asset = jetton_master_address and price_ts < tx_now order by price_ts desc limit 1), 1) *
  (select price from prices.ton_price where price_ts < tx_now order by price_ts desc limit 1) as tvl_usd
  from jetton_transfers
  where (jetton_master_address = upper('0:cd872fa7c5816052acdf5332260443faec9aacc8c21cca4d92e7f47034d11892') 
  or jetton_master_address = upper('0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000'))
  and tx_now  >= 1728558000 and tx_now < 1730286000 
  and (
    destination = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f')
  or
    source = upper('0:b606de2fc1c4a00b000194e7e097be466c6b82d06a515361ac64aaaa307bbe4f')
  ) and not tx_aborted
), tonstable_impact as (
  select address, sum(tvl_usd) as tvl_impact from tonstable_flow
  group by 1
), aqua_flow as (
  select 
  case when destination = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182') then source
  else destination end as address,
  case when source = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182') then -1 else 1 end * amount / 1e9 * 
  coalesce((select price from prices.core where asset = jetton_master_address and price_ts < tx_now order by price_ts desc limit 1), 1) *
  (select price from prices.ton_price where price_ts < tx_now order by price_ts desc limit 1) as tvl_usd
  from jetton_transfers
  where (jetton_master_address = upper('0:cd872fa7c5816052acdf5332260443faec9aacc8c21cca4d92e7f47034d11892') 
  or jetton_master_address = upper('0:bdf3fa8098d129b54b4f73b5bac5d1e1fd91eb054169c3916dfc8ccd536d1000')
  or jetton_master_address = upper('0:cf76af318c0872b58a9f1925fc29c156211782b9fb01f56760d292e56123bf87')
  )
  and tx_now  >= 1728558000 and tx_now < 1730286000 
  and (
    destination = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182')
  or
    source = upper('0:160f2c40452977a25d86d5130b3307a9af7bfa4deaf996cde388096178ab2182')
  ) and not tx_aborted
), aqua_impact as (
  select address, sum(tvl_usd) as tvl_impact from aqua_flow
  group by 1
), tonstakers_pools as (
  -- GEMSTON
  select upper('0:61d80b20e0ea679609a4c36e60a59ec8726c8d3c971e2e1ff9d68d25386c068e') as address,
   upper('0:57e8af5a5d59779d720d0b23cf2fce82e0e355990f2f2b7eb4bba772905297a4') as token
  union all
  -- PUNK
  select upper('0:e340e1aafdbc7da5d8d02614112bd2eec7e60e5300eed5434cf127afbdb1b6e5') as address,
   upper('0:9da73e90849b43b66dacf7e92b576ca0978e4fc25f8a249095d7e5eb3fe5eebb') as token
  union all
  -- XROCK
  select upper('0:34477d7b3f5d1ba298396069c8e01f7f7097348cf6d5c272d9bb726e31677236') as address,
   upper('0:157c463688a4a91245218052c5580807792cf6347d9757e32f0ee88a179a6549') as token
union all
  -- JetTon
  select upper('0:390609d615842e2a30cc826aac6114c0d52dea8eb17532f9a31be043100d7d8f') as address,
   upper('0:105e5589bc66db15f13c177a12f2cf3b94881da2f4b8e7922c58569176625eb5') as token
union all
  -- durev
  select upper('0:f0eeee82c246c87f385f771213032d3dcaabc0939f61c827716dd40247aee297') as address,
   upper('0:74d8327471d503e2240345b06fe1a606de1b5e3c70512b5b46791b429dab5eb1') as token
union all
  -- WEB3
  select upper('0:cc31242c986a1c21150cc572f831a98419ab2200d9d5e86a4ab2d0292b8e6554') as address,
   upper('0:6d70be0903e3dd3e252407cbad1dca9d69fb665124ea74bf19d4479778f2ed8b') as token
),
tonstakers_flow as (
  select 
  case when destination = tp.address then source
  else destination end as address,
  case when source = tp.address then -1 else 1 end * amount as amount,
  tp.token
  from jetton_transfers jt
  join tonstakers_pools tp on tp.token = jt.jetton_master_address
  and (jt.destination = tp.address or jt.source = tp.address)
  where tx_now  >= 1728558000 and tx_now < 1730286000 
  and not tx_aborted
), tonstakers_delta as (
select address, token, sum(amount) as amount from tonstakers_flow
group by 1, 2
), tonstakers_impact as (
  select address, sum(amount * (select price_usd from prices.agg_prices ap where ap.base = token and price_time < 1730286000 order by price_time desc limit 1)) /1e6 as tvl_impact from tonstakers_delta
  group by 1
), hipo_flow as (
  select 
  jm."owner" as address, 
  amount / 1e9 * coalesce((select price from prices.core where asset = jm.minter and price_ts < jm.utime order by price_ts desc limit 1), 1) *
    (select price from prices.ton_price where price_ts < jm.utime order by price_ts desc limit 1) as tvl_usd
  from parsed.jetton_mint jm 
  where jm.minter = '0:CF76AF318C0872B58A9F1925FC29C156211782B9FB01F56760D292E56123BF87'
  and jm.utime >= 1728558000 and jm.utime < 1730286000
  and jm.successful
  union all
  select 
  jb."owner" as address,
  -amount / 1e9 * coalesce((select price from prices.core where asset = jb.jetton_master_address and price_ts < jb.tx_now order by price_ts desc limit 1), 1) *
    (select price from prices.ton_price where price_ts < jb.tx_now order by price_ts desc limit 1) as tvl_usd
  from jetton_burns jb 
  where jb.jetton_master_address = '0:CF76AF318C0872B58A9F1925FC29C156211782B9FB01F56760D292E56123BF87'
  and jb.tx_now >= 1728558000 and jb.tx_now < 1730286000
  and not jb.tx_aborted 
), hipo_impact as (
  select address, sum(tvl_usd) as tvl_impact from hipo_flow
  group by 1
), all_projects_impact as (
 select 'jVault' as project, * from jvault_impact
   union all
 select 'SettleTon' as project, * from settleton_impact
   union all
 select 'DAOLama' as project, * from daolama_impact
   union all
 select 'TONHedge' as project, * from tonhedge_impact
   union all
 select 'TONPools' as project, * from tonpools_impact
   union all
 select 'Parraton' as project, * from parraton_impact
    union all
 select 'TONStable' as project, * from tonstable_impact
    union all
 select 'Aqua' as project, * from aqua_impact
    union all
 select 'Tonstakers Token Staking' as project, * from tonstakers_impact
    union ALL
 select 'Hipo' as project, * from hipo_impact
), all_projects_degen_only as (
select p.* from all_projects_impact p
join tol.enrollment_degen ed on ed.address = p.address
)
select address, sum(tvl_impact) as tvl_impact from all_projects_degen_only
group by 1