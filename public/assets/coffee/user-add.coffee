$ ->
  $('#address-search').postcodifyPopUp
    api: "https://staff.theopencloset.net/api/postcode/search.json"
    afterSelect: (entry) ->
      $('.postcodify_address').trigger('change')
      $('.postcodify_controls .close_button').trigger('click')

  $('.postcodify_address').change (e) ->
    address1 = $('.postcodify_building_id').val()
    address2 = $(@).val()
    address3 = $('.postcodify_jibeon_address').val()

    $('#address1').val(address1)
    $('#address2').val(address2)
    $('#address3').val(address3)
