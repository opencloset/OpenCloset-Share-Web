$ ->
  IMP = window.IMP


  ## FIXME: 테스트를 위해서 결제를 생략하고, 상태변경을 요청
  STATUS =
    payment_done: 50

  $('#btn-payment').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax location.href,
      type: 'PUT'
      data: { status_id: STATUS.payment_done }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
    ###
    $info = $('#payment-info')
    IMP.init('imp77873889')
    IMP.request_pay
      pg:             'html5_inicis'                # version 1.1.0부터 지원.
      pay_method:     $('#payment-method').val()    # 'card':신용카드, 'trans':실시간계좌이체, 'vbank':가상계좌, 'phone':휴대폰소액결제
      merchant_uid:   'merchant_' + new Date().getTime()
      name:           '주문명:test#1'
      amount:         $('#order-price').data('price')
      buyer_email:    $info.data('email')
      buyer_name:     $info.data('name')
      buyer_tel:      $info.data('phone')
      buyer_addr:     $info.data('address1')
    , (res) ->
      if res.success
        console.log "고유ID: #{res.imp_uid}"
        console.log "상점거래ID: #{res.merchant_uid}"
        console.log "결제금액: #{res.paid_amount}"
        console.log "카드승인번호: #{res.apply_num}"
      else
        console.log res.error_msg
    ###
