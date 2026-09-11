import { DepositService } from './deposit.service';
import { ClientIpoController } from '../ipo/client-ipo.controller';

describe('IPO automatic payment from approved deposits',()=>{
  function setup(amount:number){
    const tx={depositRequest:{updateMany:jest.fn().mockResolvedValue({count:1})},account:{findUnique:jest.fn().mockResolvedValue({id:'account',userId:'client',cashBalance:0}),update:jest.fn()},user:{count:jest.fn().mockResolvedValue(1)},ipoDebt:{findMany:jest.fn().mockResolvedValue([{id:'debt',amount:100,paidAmount:0,ipoApplicationId:'app',ipoApplication:{id:'app',allocatedQuantity:10,allocatedPrice:10,allocatedAmount:100,ipo:{symbol:'ABC',instrumentId:'stock'}}}]),update:jest.fn()},ipoApplication:{update:jest.fn()},accountTransaction:{create:jest.fn()},notification:{create:jest.fn()}};
    const prisma={depositRequest:{findUnique:jest.fn().mockResolvedValue({status:'PENDING',amount,accountId:'account'})},$transaction:(fn:any)=>fn(tx)};
    const service=new DepositService(prisma as any,{createLog:jest.fn()} as any);
    const settle=jest.spyOn(service as any,'settleIpoApplication').mockResolvedValue({});
    return {service,tx,settle};
  }
  it('removes the manual repayment route',()=>{
    expect(Object.getOwnPropertyNames(ClientIpoController.prototype)).not.toContain('payDebt');
  });
  it('partial deposit reduces debt without generating holdings',async()=>{
    const {service,tx,settle}=setup(40);
    expect(await service.approveDeposit('deposit','finance','FINANCE')).toMatchObject({ipoRepayment:40,creditedAmount:0});
    expect(tx.ipoDebt.update.mock.calls[0][0].data).toMatchObject({paidAmount:{increment:40},status:'PARTIAL'});
    expect(settle).not.toHaveBeenCalled();
  });
  it('full payment creates holdings and credits only surplus',async()=>{
    const {service,tx,settle}=setup(150);
    expect(await service.approveDeposit('deposit','finance','FINANCE')).toMatchObject({ipoRepayment:100,creditedAmount:50});
    expect(settle).toHaveBeenCalledTimes(1);
    expect(tx.account.update.mock.calls[0][0].data).toEqual({cashBalance:{increment:50},buyingPower:{increment:50}});
    expect(tx.notification.create).toHaveBeenCalledWith(expect.objectContaining({data:expect.objectContaining({type:'IPO_ALLOTMENT_SETTLED'})}));
  });
  it('duplicate approval does not repay or create holdings again',async()=>{
    const {service,tx,settle}=setup(150);
    tx.depositRequest.updateMany.mockResolvedValue({count:0});
    await expect(service.approveDeposit('deposit','finance','FINANCE')).rejects.toThrow('already processed');
    expect(tx.ipoDebt.update).not.toHaveBeenCalled();
    expect(settle).not.toHaveBeenCalled();
  });
});
