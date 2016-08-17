$ ->
  console.log Handlebars
  console.log Handlebars.compile    # why undefined?

  $('#address-search').postcodifyPopUp
    api: "http://localhost:5001/api/postcode/search.json"
    afterSelect: (entry) ->
      $('.postcodify_address').trigger('change')
      $('.postcodify_controls .close_button').trigger('click')

  $('.postcodify_address').change (e) ->
    address1 = $('.postcodify_building_id').val()
    address2 = $(@).val()
    address3 = $('.postcodify_jibeon_address').val()

    source   = $('#tpl-address').html()
    template = Handlebars.compile(source)
    html     = template({ address1: address1, address2: address2, address3: address3 })
    console.log html
