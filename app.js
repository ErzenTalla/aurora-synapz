require('dotenv').config();
const express = require('express');
const cors    = require('cors');
const path    = require('path');

const authRoutes    = require('./routes/auth');
const contactRoutes = require('./routes/contact');
const portalRoutes  = require('./routes/portal');

const app = express();
app.use(cors());
app.use(express.json());

app.use(express.static(path.join(__dirname, 'public')));

// API routes
app.use('/api/auth',    authRoutes);
app.use('/api/contact', contactRoutes);
app.use('/api/portal',  portalRoutes);

app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

module.exports = app;
