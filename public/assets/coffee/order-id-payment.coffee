$ ->
  IMP = window.IMP
  IMP.init(CONFIG.iamport.id)

  STATUS =
    choose_address: 49  # 주소선택
    payment_done: 50    # 결제완료
    waiting_deposit: 56 # 입금대기

  $('#btn-payment').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')

    # card: 신용카드
    # trans: 실시간계좌이체
    # vbank: 가상계좌
    # phone: 휴대폰소액결제
    pay_method = $('#payment-method').val()
    unless pay_method in [ "card", "trans", "vbank", "phone" ]
      $.growl.error({ title: "결제 실패", message: "결제 수단을 선택하세요." })
      $this.removeClass('disabled')
      return

    $info = $('#payment-info')
    name     = $info.data("name")
    order_id = $info.data("order-id")

    unless order_id? && /^\d+$/.test(order_id) && order_id > 0
      $.growl.error({ title: "결제 실패", message: "주문서가 없습니다." })
      $this.removeClass('disabled')
      return

    unless name? && name.length > 0
      $.growl.error({ title: "결제 실패", message: "사용자 이름이 없습니다." })
      $this.removeClass('disabled')
      return

    $.ajax "/orders/#{order_id}/payments",
      type: 'POST'
      data:
        pay_method: pay_method
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->

        imp_params =
          pg:           'html5_inicis'
          pay_method:   pay_method
          merchant_uid: data.cid
          name:         "#{name}##{order_id}"
          amount:       $('#order-price').data('price')
          buyer_email:  $info.data('email')
          buyer_name:   name
          buyer_tel:    $info.data('phone')
          buyer_addr:   $info.data('address1')
          vbank_due:    $('#shipping-date').data('vbank-due')
          m_redirect_url: "#{location.protocol}//#{location.host}/payments/#{data.id}/callback"
        imp_params.notice_url = CONFIG.iamport.notice_url if CONFIG.iamport.notice_url?

        IMP.request_pay imp_params, (res) ->
          payment_status = res.status
          unless res.success
            payment_status = "cancelled"
            $.growl.error({ title: '결제실패', message: res.error_msg })

          $.ajax "/payments/#{data.id}",
            type: 'PUT'
            dataType: 'json'
            data:
              order_id: order_id
              imp_uid: res.imp_uid
              merchant_uid: res.merchant_uid
              amount: res.paid_amount
              status: payment_status
              pg_provider: res.pg_provider
              pay_method: res.pay_method
            success: (data, textStatus, jqXHR) ->

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
              $this.removeClass('disabled')

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

  $('input[name=code]').mask('AAAA')
  $('#coupon-modal').on 'shown.bs.modal', (e) ->
    $('input[name=code]:first').focus()
  $('#coupon-modal form').submit (e) ->
    e.preventDefault()

    $this = $(@)
    $submit = $this.find('.btn-submit')
    return if $submit.hasClass('disabled')

    action = $this.prop('action')
    $.ajax action,
      type: 'POST'
      data: $this.serialize()
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $submit.addClass('disabled')
        # 쿠폰의 정보를 나타내고 사용여부를 다시 묻는다
        data.price = parseInt(data.price)
        template   = JST['coupon/info']
        html       = template(data)
        $('#coupon-modal .modal-footer').remove()
        $('#coupon-modal .modal-content').append(html)
      error: (jqXHR, textStatus, errorThrown) ->
        template = JST['coupon/error']
        html     = template({ error: jqXHR.responseJSON.error })
        $('#coupon-modal .modal-footer').remove()
        $('#coupon-modal .modal-content').append(html)
      complete: (jqXHR, textStatus) ->

  $('#coupon-modal').on 'click', '#btn-coupon-use', (e) ->
    e.preventDefault()
    coupon_id = $(@).data('coupon-id')
    $.ajax "#{location.href}/coupon",
      type: 'POST'
      data: { coupon_id: coupon_id }
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        location.reload()
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->
