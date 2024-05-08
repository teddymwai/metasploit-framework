# frozen_string_literal: true

module Metasploit
  module Framework
    module LDAP

      # Provide the ability to "wrap" LDAP comms in an NTLM encryption routine
      # The methods herein are set up with the auth_context_setup call below,
      # and are called when reading or writing needs to occur.
      class NtlmEncryptor
        def initialize(ntlm_client)
          self.ntlm_client = ntlm_client
        end

        # Configure our encryption, and tell the LDAP connection object that we now want to intercept its calls
        # to read and write
        # @param ignore [String,nil] GSS token - not required by NTLM (should be nil)
        # @param ldap_connection [Net::LDAP::Connection]
        def ntlm_setup(ignore, ldap_connection)
          ldap_connection.wrap_read_write(self.method(:read), self.method(:write))
        end

        # Decrypt the provided ciphertext
        # @param ciphertext [String]
        def read(ciphertext)
          message = ntlm_client.session.unseal_message(ciphertext[16..-1])
          if ntlm_client.session.verify_signature(ciphertext[0..15], message)
            return message
          else
            # Some error
            raise Rex::Proto::LDAP::LdapException.new('Received invalid NTLM message')
          end
        end

        # Encrypt the provided plaintext
        # @param data [String]
        def write(data)
          emessage = ntlm_client.session.seal_message(data)
          signature = ntlm_client.session.sign_message(data)

          signature + emessage
        end

        attr_accessor :ntlm_client
      end
    end
  end
end
