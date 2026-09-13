
const express = require('express');
const crypto = require('crypto');

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 8080;
const drivers = new Map();
const rides = new Map();

const transitions = { requested:['assigned','cancelled'], assigned:['arriving','cancelled'], arriving:['started','cancelled'], started:['completed'], completed:[], cancelled:[] };

function distanceKm(aLat, aLng, bLat, bLng) {
  const R = 6371;
  const dLat = (bLat-aLat) * Math.PI/180;
  const dLng = (bLng-aLng) * Math.PI/180;
  const x = Math.sin(dLat/2)**2 +
    Math.cos(aLat*Math.PI/180)*Math.cos(bLat*Math.PI/180)*
    Math.sin(dLng/2)**2;
  return 2*R*Math.asin(Math.sqrt(x));
}

app.get('/health', (req,res) => res.json({ok:true, service:'HR RIDE matching backend'}));

app.post('/drivers/online', (req,res) => {
  const {driverId, name, lat, lng, vehicle='Maruti Ertiga'} = req.body;
  if (!driverId || !Number.isFinite(lat) || !Number.isFinite(lng))
    return res.status(400).json({error:'driverId, lat and lng are required'});
  drivers.set(driverId, {driverId,name:name||'HR RIDE Driver',lat,lng,vehicle,online:true,updatedAt:Date.now()});
  res.json(drivers.get(driverId));
});

app.post('/drivers/offline', (req,res) => {
  const {driverId} = req.body;
  if (drivers.has(driverId)) drivers.get(driverId).online = false;
  res.json({ok:true});
});

app.patch('/drivers/:driverId/location', (req,res) => {
  const d = drivers.get(req.params.driverId);
  if (!d) return res.status(404).json({error:'Driver not found'});
  const {lat,lng} = req.body;
  if (!Number.isFinite(lat) || !Number.isFinite(lng))
    return res.status(400).json({error:'lat and lng are required'});
  d.lat=lat; d.lng=lng; d.updatedAt=Date.now(); d.online=true;
  res.json(d);
});

app.post('/rides', (req,res) => {
  const {pickup,destination,distanceKm=0,fare=0,pickupLat,pickupLng} = req.body;
  const id = 'ride_' + crypto.randomUUID();
  const ride = {
    id,pickup,destination,distanceKm,fare,
    pickupLat,pickupLng,
    status:'requested', driverId:null,
    createdAt:Date.now(), updatedAt:Date.now()
  };
  rides.set(id, ride);
  if (Number.isFinite(pickupLat) && Number.isFinite(pickupLng)) {
    let best=null, bestKm=Infinity;
    for (const d of drivers.values()) {
      if (!d.online) continue;
      const km = distanceKm(pickupLat,pickupLng,d.lat,d.lng);
      if (km < bestKm) { best=d; bestKm=km; }
    }
    if (best) {
      ride.driverId=best.driverId;
      ride.driverDistanceKm=Number(bestKm.toFixed(2));
      ride.status='assigned';
    }
  }
  res.status(201).json(ride);
});

app.get('/rides/:id', (req,res) => {
  const ride=rides.get(req.params.id);
  if (!ride) return res.status(404).json({error:'Ride not found'});
  const driver=ride.driverId ? drivers.get(ride.driverId) : null;
  res.json({...ride, driver: driver || null});
});

app.patch('/rides/:id/status', (req,res) => {
  const ride=rides.get(req.params.id);
  if (!ride) return res.status(404).json({error:'Ride not found'});
  const next=req.body.status;
  if (!Object.prototype.hasOwnProperty.call(transitions,next)) return res.status(400).json({error:'Invalid status'});
  if (!(transitions[ride.status]||[]).includes(next)) return res.status(409).json({error:`Invalid transition ${ride.status} -> ${next}`});
  ride.status=next; ride.updatedAt=Date.now();
  res.json(ride);
});

app.get('/drivers/nearby', (req,res) => {
  const lat=Number(req.query.lat), lng=Number(req.query.lng);
  if (!Number.isFinite(lat)||!Number.isFinite(lng))
    return res.status(400).json({error:'lat and lng query params are required'});
  const result=[...drivers.values()].filter(d=>d.online).map(d=>({
    ...d, distanceKm:Number(distanceKm(lat,lng,d.lat,d.lng).toFixed(2))
  })).sort((a,b)=>a.distanceKm-b.distanceKm);
  res.json(result);
});


// Razorpay: keep RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET only on the server.
// Client receives only the order id and uses the public key id in checkout.
app.post('/payments/order', async (req,res) => {
  try {
    const {amountPaise, receipt, notes={}} = req.body;
    if (!Number.isInteger(amountPaise) || amountPaise <= 0)
      return res.status(400).json({error:'amountPaise must be a positive integer'});
    const keyId=process.env.RAZORPAY_KEY_ID;
    const keySecret=process.env.RAZORPAY_KEY_SECRET;
    if (!keyId || !keySecret)
      return res.status(503).json({error:'Razorpay server credentials are not configured'});
    const auth=Buffer.from(`${keyId}:${keySecret}`).toString('base64');
    const rr=await fetch('https://api.razorpay.com/v1/orders',{
      method:'POST',
      headers:{'Content-Type':'application/json','Authorization':`Basic ${auth}`},
      body:JSON.stringify({amount:amountPaise,currency:'INR',receipt:receipt||`hr_${Date.now()}`,notes})
    });
    const data=await rr.json();
    if(!rr.ok) return res.status(rr.status).json(data);
    res.json({id:data.id, amount:data.amount, currency:data.currency, keyId});
  } catch(e) { res.status(500).json({error:'Unable to create payment order'}); }
});

app.post('/payments/verify', (req,res) => {
  const {orderId,paymentId,signature}=req.body;
  const secret=process.env.RAZORPAY_KEY_SECRET;
  if(!secret) return res.status(503).json({error:'Razorpay server credentials are not configured'});
  if(!orderId||!paymentId||!signature) return res.status(400).json({error:'Missing payment verification fields'});
  const expected=crypto.createHmac('sha256',secret).update(`${orderId}|${paymentId}`).digest('hex');
  const ok=crypto.timingSafeEqual(Buffer.from(expected),Buffer.from(signature));
  res.json({verified:ok});
});

app.listen(PORT,()=>console.log(`HR RIDE backend listening on ${PORT}`));
