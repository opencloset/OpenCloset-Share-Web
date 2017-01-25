$ ->
  $('#address-search').postcodifyPopUp
    api: CONFIG.postcodify_url
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

  $('#btn-verification-code:not(.disabled)').click ->
    $this = $(@)
    $this.addClass('disabled')

    $phone = $('input[name=phone]')
    phone  = $phone.val()
    unless phone
      $this.removeClass('disabled')
      $.growl.error({ title: '인증번호전송실패', message: '휴대폰번호가 없습니다' })
      return

    $.ajax '/verify',
      type: 'POST'
      data: { phone: phone }
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $phone.prop('readonly', true)
        $.growl.notice({ title: '인증번호를 전송하였습니다', message: '인증번호 확인 후 입력해주세요' })
        $('#btn-submit').removeClass('disabled')
      error: (jqXHR, textStatus, errorThrown) ->
        $.growl.error({ title:textStatus, message: jqXHR.responseJSON.error })
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')
