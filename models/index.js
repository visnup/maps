var mongoose = require('mongoose');

require('./favorite');

var url = process.env.MONGO_URL || 'localhost/uber';
module.exports = mongoose.connect(url);

require('../lib/mongo-log')(module.exports.mongo);
