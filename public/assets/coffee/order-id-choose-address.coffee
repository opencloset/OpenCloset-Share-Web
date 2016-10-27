$.fn.editable.defaults.mode = 'inline'
$.fn.editable.defaults.emptytext = '상세주소'
$.fn.editable.defaults.ajaxOptions =
  type: "PUT"
  dataType: 'json'

$ ->
  $('#address-search').postcodifyPopUp
    api: "http://localhost:5001/api/postcode/search.json"
    afterSelect: (entry) ->
      $('.postcodify_address').trigger('change')
      $('.postcodify_controls .close_button').trigger('click')

  $('.postcodify_address').change (e) ->
    address1 = $('.postcodify_building_id').val()
    address2 = $(@).val()
    address3 = $('.postcodify_jibeon_address').val()

    $.ajax '/address',
      type: 'POST'
      data: { address1: address1, address2: address2, address3: address3 }
      success: (data, textStatus, jqXHR) ->
        template = JST['address']
        html     = template(data)
        $('#address').append(html).find('li:last-child .address-editable').editable
          params: (params) ->
            params[params.name] = params.value
            params
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  $('.address-editable').editable
    params: (params) ->
      params[params.name] = params.value
      params

  $('#address').on 'click', '.btn-delete-address:not(.disabled)', (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax $this.prop('href'),
      type: 'DELETE'
      success: (data, textStatus, jqXHR) ->
        $this.closest('li').remove()
        $('#user_profile_address').prop('checked', true)
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled') if $this


  STATUS =
    payment: 19
    choose_clothes: 48

  $('#btn-next-step').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax $this.prop('href'),
      type: 'PUT'
      data: "#{$('#form-address').serialize()}&status_id=#{STATUS.payment}"
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $('#btn-choose-clothes:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax location.href,
      type: 'PUT'
      data: { status_id: STATUS.choose_clothes }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
