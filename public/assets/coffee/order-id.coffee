$ ->
  order_id = location.pathname.split('/').pop()
  $('#clothes-recommend').load "/clothes/recommend?order_id=#{order_id}"

  STATUS =
    payment: 19

  $('.btn-recommend:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax $this.prop('href'),
      type: 'PUT'
      data: { status_id: STATUS.payment }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
