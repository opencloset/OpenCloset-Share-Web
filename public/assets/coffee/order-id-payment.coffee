$ ->
  IMP = window.IMP
  IMP.init('imp77873889')

  STATUS =
    choose_address: 49
    payment_done: 50

  $('#btn-payment').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')

    $info = $('#payment-info')
    order_id = $info.data('order-id')
    name     = $info.data('name')
    IMP.request_pay
      pg:           'html5_inicis'
      pay_method:   $('#payment-method').val()    # 'card':신용카드, 'trans':실시간계좌이체, 'vbank':가상계좌, 'phone':휴대폰소액결제
      merchant_uid: 'merchant_' + new Date().getTime()
      name:         "#{name}##{order_id}"
      amount:       $('#order-price').data('price')
      buyer_email:  $info.data('email')
      buyer_name:   name
      buyer_tel:    $info.data('phone')
      buyer_addr:   $info.data('address1')
    , (res) ->
      console.log res
      if res.success
        $.ajax location.href,
          type: 'PUT'
          data: { status_id: STATUS.payment_done }
          success: (data, textStatus, jqXHR) ->
            # location.reload()
            console.log '** SUCCESS'
          error: (jqXHR, textStatus, errorThrown) ->
          complete: (jqXHR, textStatus) ->
            $this.removeClass('disabled')
      else
        console.log '** FAIL'

  ### FIXME: 테스트를 위해서 결제를 생략하고, 상태변경을 요청
  STATUS =
    choose_address: 49
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

  $('#datepicker-wearon-date').datepicker
    language: 'kr'
    startDate: '+3d'
    todayHighlight: true
    format: 'yyyy-mm-dd'

  $('#datepicker-wearon-date').on 'changeDate', ->
    val = $('#datepicker-wearon-date').datepicker('getFormattedDate')
    $('#wearon_date').val(val)

  $('#form-wearon-date').submit (e) ->
    e.preventDefault()
    $this = $(@)
    action = $this.prop('action')
    $.ajax action,
      type: 'PUT'
      data: { wearon_date: $('#wearon_date').val() }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  $('#btn-choose-address:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    $.ajax location.href,
      type: 'PUT'
      data: { status_id: STATUS.choose_address }
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
