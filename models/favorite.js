var mongoose = require('mongoose')

var FavoriteSchema = module.exports = new mongoose.Schema({
  name: String,
  formatted_address: String,
  latLng: [ Number, Number ],
  checked: Boolean
});

mongoose.model('Favorite', FavoriteSchema);
