
Buffer::toByteArray = () ->
  	return Array.prototype.slice.call @, 0

String::ucfirst = ->
	@charAt(0).toUpperCase() + @substr 1
