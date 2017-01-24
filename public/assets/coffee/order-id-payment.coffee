$ ->
  IMP = window.IMP
  IMP.init('imp77873889')

  STATUS =
    choose_address: 49  # 주소선택
    payment_done: 50    # 결제완료
    waiting_deposit: 56 # 입금대기

  $('#btn-payment').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')

    $info = $('#payment-info')
    order_id = $info.data('order-id')
    name     = $info.data('name')

    $.ajax "/orders/#{order_id}/payments",
      type: 'POST'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->

        IMP.request_pay
          pg:           'html5_inicis'
          pay_method:   $('#payment-method').val()    # 'card':신용카드, 'trans':실시간계좌이체, 'vbank':가상계좌, 'phone':휴대폰소액결제
          merchant_uid: data.cid
          name:         "#{name}##{order_id}"
          amount:       $('#order-price').data('price')
          buyer_email:  $info.data('email')
          buyer_name:   name
          buyer_tel:    $info.data('phone')
          buyer_addr:   $info.data('address1')
          notice_url:   'https://test-share.theopencloset.net/webhooks/iamport'
        , (res) ->
          data =
            order_id: order_id
            dump: JSON.stringify(res)
            imp_uid: res.imp_uid
            merchant_uid: res.merchant_uid
            amount: res.paid_amount
            status: res.status
            pg_provider: res.pg_provider
            pay_method: res.pay_method

          unless res.success
            $.growl.error({ title: '결제실패', message: res.error_msg })

          $.ajax '/payments',
            type: 'POST'
            dataType: 'json'
            data: data
            success: (data, textStatus, jqXHR) ->
            error: (jqXHR, textStatus, errorThrown) ->
            complete: (jqXHR, textStatus) ->
              $this.removeClass('disabled')

          ## ready 라면 입금대기로 상태변경
          ## paid 라면 결제완료로 상태변경
          if res.success and res.status in ['paid', 'ready']
            status = if res.status is 'paid' then 'payment_done' else 'waiting_deposit'
            $.ajax location.href,
              type: 'PUT'
              data: { status_id: STATUS[status] }
              success: (data, textStatus, jqXHR) ->
                location.reload()
              error: (jqXHR, textStatus, errorThrown) ->
              complete: (jqXHR, textStatus) ->

      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->


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

  ###
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
  ###
