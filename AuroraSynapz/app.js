require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const setup         = require('./db/setup');
const authRoutes    = require('./routes/auth');
const contactRoutes = require('./routes/contact');
const portalRoutes  = require('./routes/portal');
const stripeRoutes  = require('./routes/stripe');
const alpacaRoutes  = require('./routes/alpaca');
const adminRoutes   = require('./routes/admin');

const app = express();
app.use(cors());

// Ensure all tables exist (idempotent — CREATE TABLE IF NOT EXISTS)
setup().catch(err => console.error('DB setup error:', err));

// Stripe webhook needs the raw body before express.json() parses it
app.use('/api/stripe/webhook', express.raw({ type: 'application/json' }));

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

app.use('/api/auth',    authRoutes);
app.use('/api/contact', contactRoutes);
app.use('/api/portal',  portalRoutes);
app.use('/api/stripe',  stripeRoutes);
app.use('/api/alpaca',  alpacaRoutes);
app.use('/api/admin',   adminRoutes);

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

module.exports = app;
