const express    = require('express');
const nodemailer = require('nodemailer');
const db         = require('../db/index');

const router = express.Router();

router.post('/', async (req, res) => {
  try {
    const { first_name, last_name, email, phone, service, assets, message } = req.body;
    if (!first_name || !last_name || !email) {
      return res.status(400).json({ error: 'Name and email are required' });
    }

    await db.query(
      `INSERT INTO contacts (first_name, last_name, email, phone, service, assets, message)
       VALUES ($1,$2,$3,$4,$5,$6,$7)`,
      [first_name, last_name, email, phone || null, service || null, assets || null, message || null]
    );

    if (process.env.SMTP_HOST && process.env.SMTP_USER) {
      const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: parseInt(process.env.SMTP_PORT || '587'),
        secure: false,
        auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
      });
      transporter.sendMail({
        from: `"Aurora Synapz Website" <${process.env.SMTP_USER}>`,
        to: process.env.MAIL_TO || process.env.SMTP_USER,
        subject: `New Inquiry — ${first_name} ${last_name}`,
        html: `<h2>New Contact Inquiry</h2>
               <p><b>Name:</b> ${first_name} ${last_name}</p>
               <p><b>Email:</b> ${email}</p>
               <p><b>Phone:</b> ${phone || '—'}</p>
               <p><b>Service:</b> ${service || '—'}</p>
               <p><b>Assets:</b> ${assets || '—'}</p>
               <p><b>Message:</b> ${message || '—'}</p>`,
      }).catch(err => console.error('Email error:', err.message));
    }

    res.status(201).json({ success: true, message: 'Inquiry received.' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
