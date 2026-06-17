const nodemailer = require('nodemailer');

function isConfigured() {
  return !!(process.env.SMTP_HOST && process.env.SMTP_USER);
}

let transporter = null;
function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: parseInt(process.env.SMTP_PORT || '587'),
      secure: false,
      auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
    });
  }
  return transporter;
}

async function sendMail({ to, subject, html }) {
  if (!isConfigured()) return;
  try {
    await getTransporter().sendMail({
      from: `"Aurora Synapz" <${process.env.SMTP_USER}>`,
      to,
      subject,
      html,
    });
  } catch (err) {
    console.error('Email error:', err.message);
  }
}

function money(n) {
  return `$${parseFloat(n).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
}

function wrap(title, bodyHtml) {
  return `<div style="font-family:Arial,sans-serif;max-width:520px;margin:0 auto">
    <h2 style="color:#0f2a4a">${title}</h2>
    ${bodyHtml}
    <p style="color:#888;font-size:12px;margin-top:24px">Aurora Synapz Asset Management LLC</p>
  </div>`;
}

async function sendDepositConfirmation({ to, name, amount }) {
  await sendMail({
    to,
    subject: 'Deposit confirmed — Aurora Synapz',
    html: wrap('Deposit Confirmed', `
      <p>Hi ${name},</p>
      <p>We've received your deposit of <b>${money(amount)}</b> and allocated it to your portfolio.</p>
      <p>Log in to your portal to view your updated holdings.</p>
    `),
  });
}

async function sendWithdrawalRequested({ to, name, amount, withdrawalId }) {
  await sendMail({
    to,
    subject: 'Withdrawal request received — Aurora Synapz',
    html: wrap('Withdrawal Requested', `
      <p>Hi ${name},</p>
      <p>We've received your withdrawal request #${withdrawalId} for <b>${money(amount)}</b>. It is now pending review.</p>
      <p>We'll email you again once it's approved and processed.</p>
    `),
  });
}

const STATUS_LABELS = { approved: 'Approved', processed: 'Processed', rejected: 'Rejected' };
const STATUS_MESSAGES = {
  approved:  (amount, id) => `Your withdrawal request #${id} for ${money(amount)} has been approved and is being processed.`,
  processed: (amount, id) => `Your withdrawal of ${money(amount)} (request #${id}) has been processed and funds are on their way.`,
  rejected:  (amount, id) => `Your withdrawal request #${id} for ${money(amount)} was rejected and the funds have been restored to your account.`,
};

async function sendWithdrawalStatus({ to, name, amount, withdrawalId, status }) {
  const label = STATUS_LABELS[status] || status;
  const message = STATUS_MESSAGES[status] ? STATUS_MESSAGES[status](amount, withdrawalId) : '';
  await sendMail({
    to,
    subject: `Withdrawal ${label} — Aurora Synapz`,
    html: wrap(`Withdrawal ${label}`, `
      <p>Hi ${name},</p>
      <p>${message}</p>
    `),
  });
}

async function sendFeeNotice({ to, name, amount, feeRate }) {
  await sendMail({
    to,
    subject: 'Monthly management fee charged — Aurora Synapz',
    html: wrap('Management Fee Charged', `
      <p>Hi ${name},</p>
      <p>Your monthly management fee of <b>${money(amount)}</b> (${(feeRate * 100).toFixed(2)}% annual rate) has been deducted from your account.</p>
    `),
  });
}

module.exports = {
  sendMail,
  isConfigured,
  sendDepositConfirmation,
  sendWithdrawalRequested,
  sendWithdrawalStatus,
  sendFeeNotice,
};
