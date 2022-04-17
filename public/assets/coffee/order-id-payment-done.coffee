$ ->
  $('#btn-cancel-payment').click (e) ->
    return unless confirm "취소하시겠습니까?"
    $this = $(@)
    return if $this.hasClass('disabled')
    $this.addClass('disabled')
    $.ajax $this.data('url'),
      type: 'POST'
      dataType: 'json'
      data: $('#refund-form').serialize()
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title: "결제를 취소하지 못했습니다.", message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  $('.btn-bank .btn').click (e) ->
    $('.btn-bank .btn').removeClass('active')
    $(@).addClass('active')
    $('input[name=refund_bank]').val($(@).data('code'))

  $('#btn-refund-coupon').click (e) ->
    $this = $(@)
    return if $this.hasClass('disabled')
    $this.addClass('disabled')
    arr = $('#refund-form').serializeArray()
    vals = []
    $.each arr, (i, el) ->
      vals.push(el.value)
    account = vals.join('|')

    $.ajax $this.data('url'),
      type: 'PUT'
      dataType: 'json'
      data: {coupon_refund_account: account}
      success: (data, textStatus, jqXHR) ->
        $.growl.notice({ title: "환불계좌가 등록 되었습니다.", message: "의류 발송시 입금해드립니다." })
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title: "결제를 취소하지 못했습니다.", message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
