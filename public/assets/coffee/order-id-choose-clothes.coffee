$ ->
  order_id = location.pathname.split('/').pop()

  STATUS =
    choose_address: 49

  $('.btn-recommend:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax $this.prop('href'),
      type: 'PUT'
      data:
        status_id: STATUS.choose_address
        clothes_code: null
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $('.js-add-category').click (e) ->
    e.preventDefault()
    name  = $(@).data('name')
    price = $(@).data('price')
    url   = $(@).prop('href')
    $.ajax url,
      type: 'POST'
      dataType: 'json'
      data: { name: name, price: price }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title: "품목추가 실패", message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
