const requireAuth = require('./auth');

const requireAdmin = [
  requireAuth,
  (req, res, next) => {
    if (req.user.role !== 'admin') return res.status(403).json({ error: 'Forbidden' });
    next();
  },
];

module.exports = requireAdmin;
