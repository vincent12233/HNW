import { IpoService } from './ipo.service';

describe('IPO publication', () => {
  function setup() {
    const application:any={id:'one',status:'PENDING',draftQuantity:10,draftPrice:20,ipo:{instrumentId:'stock',symbol:'ABC'},account:{id:'account',userId:'customer',cashBalance:100,user:{assignedBusinessId:'business'}}};
    const tx={ipoApplication:{findUnique:jest.fn().mockImplementation(async()=>application),updateMany:jest.fn().mockImplementation(async({data})=>{Object.assign(application,data);return {count:1};}),findUniqueOrThrow:jest.fn().mockImplementation(async()=>application)},account:{update:jest.fn()},ipoDebt:{create:jest.fn()},notification:{create:jest.fn()},auditLog:{create:jest.fn()}};
    Object.assign(tx,{accountTransaction:{create:jest.fn()}});
    const service=new IpoService({$transaction:(fn:any)=>fn(tx)} as any);
    return {service,tx,application};
  }
  it('saving allocation does not debit or notify',async()=>{
    const {service,tx}=setup();
    await service.allocate('one',10,20,'business');
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.ipoDebt.create).not.toHaveBeenCalled();
    expect(tx.notification.create).not.toHaveBeenCalled();
  });
  it('publication debits once and creates outstanding debt',async()=>{
    const {service,tx}=setup();
    expect((await service.publish(['one'],'business','business')).published).toBe(1);
    expect(tx.ipoDebt.create.mock.calls[0][0].data.amount).toBe(100);
    expect(tx.notification.create).toHaveBeenCalledTimes(1);
    expect(tx.notification.create.mock.calls[0][0].data).toMatchObject({type:'IPO_PAYMENT_REQUIRED'});
    expect((await service.publish(['one'],'business','business')).published).toBe(0);
    expect(tx.account.update).toHaveBeenCalledTimes(1);
  });
  it('rejects unallocated and out-of-scope applications',async()=>{
    const {service,tx,application}=setup();
    application.draftQuantity=null;
    expect((await service.publish(['one'],'business','business')).published).toBe(0);
    application.draftQuantity=10;
    expect((await service.publish(['one'],'other','other')).published).toBe(0);
    expect(tx.account.update).not.toHaveBeenCalled();
  });
  it('sufficient cash settles holdings and sends a success notification',async()=>{
    const {service,tx,application}=setup();
    application.account.cashBalance=300;
    const settle=jest.spyOn(service,'settleIpoApplication').mockResolvedValue(undefined as any);
    expect((await service.publish(['one'],'business','business')).published).toBe(1);
    expect(tx.account.update.mock.calls[0][0].data.cashBalance).toEqual({decrement:200});
    expect(settle).toHaveBeenCalledTimes(1);
    expect(tx.ipoDebt.create).not.toHaveBeenCalled();
    expect(tx.notification.create.mock.calls[0][0].data.type).toBe('IPO_ALLOTMENT_SETTLED');
  });
  it('preserves reserved funds and only debits available cash',async()=>{
    const {service,tx,application}=setup();
    application.account.cashBalance=300;
    application.account.frozenBalance=250;
    application.account.buyingPower=50;
    await service.publish(['one'],'business','business');
    expect(tx.account.update.mock.calls[0][0].data).toEqual({cashBalance:{decrement:50},buyingPower:0});
    expect(tx.ipoDebt.create.mock.calls[0][0].data.amount).toBe(150);
  });
});
