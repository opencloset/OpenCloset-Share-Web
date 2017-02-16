$ ->
  $('#btn-cancel-payment').click (e) ->
    return unless confirm "취소하시겠습니까?"
    $this = $(@)
    return if $this.hasClass('disabled')
    $this.addClass('disabled')
    $.ajax $this.data('url'),
      type: 'POST'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title: "결제를 취소하지 못했습니다.", message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
