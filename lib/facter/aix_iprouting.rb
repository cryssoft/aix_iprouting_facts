#
#  FACT(S):     aix_iprouting
#
#  PURPOSE:     This small module rips apart the "netstat -nr" output and tries
#		to do some inteillgent things with the output in a hash.  This
#		is a logical precursor to building rules that manipulate the
#		routing table even though that's not a first-class Puppet
#		resource yet.
#
#  RETURNS:     (hash)
#
#  AUTHOR:      Chris Petersen, Crystallized Software
#
#  DATE:        February 2, 2023
#
#  NOTES:       Myriad names and acronyms are trademarked or copyrighted by IBM
#               including but not limited to IBM, PowerHA, AIX, RSCT (Reliable,
#               Scalable Cluster Technology), and CAA (Cluster-Aware AIX).  All
#               rights to such names and acronyms belong with their owner.
#
#-------------------------------------------------------------------------------
#
#  LAST MOD:    (never)
#
#  MODIFICATION HISTORY:
#
#       (none)
#
#-------------------------------------------------------------------------------
#
Facter.add(:aix_iprouting) do
    #  This only applies to the AIX operating system
    confine :osfamily => 'AIX'

    #  Define an empty hash value for our default return
    l_aixIPRouting = {}

    #  Start with an unknown protocol family
    l_pf = '(unknown)'

    #  Do the work
    setcode do
        #  Run the command to output the IP routing table in numeric form
        l_lines = Facter::Util::Resolution.exec('/usr/bin/netstat -nr 2>/dev/null')

        #  Loop over the lines that were returned
        l_lines && l_lines.split("\n").each do |l_oneLine|

            #  Strip leading and trailing whitespace and re-split
            l_stripped = l_oneLine.strip()
            l_list     = l_stripped.split()

            #  If this is a protocol family header, stash an appropriate value
            if (l_list[0] == 'Route')
                if (l_list[5] == '2')
                    l_pf = 'IPv4'
                else
                    if (l_list[5] == '24')
                        l_pf = 'IPv6'
                    else
                        l_pf = '(unknown)'
                    end
                end
            else
                #  If this is a route description (defined negatively), annotate and stash it in the hash
                if ((l_list[0] != 'Routing') and (l_list[0] != 'Destination') and (l_list.length != 0))

                    #  Stash the data
                    l_aixIPRouting[l_list[0]]              = {}
                    l_aixIPRouting[l_list[0]]['family']    = l_pf
                    l_aixIPRouting[l_list[0]]['gateway']   = l_list[1]
                    l_aixIPRouting[l_list[0]]['flags']     = l_list[2]
                    l_aixIPRouting[l_list[0]]['interface'] = l_list[5]

                    #  Annotate the type of route this is based on the destination and gateway
                    if (l_list[1] == '127.0.0.1')
                        l_aixIPRouting[l_list[0]]['type'] = 'local'
                    else
                        l_pieces = l_list[0].split('/')
                        if (l_pieces.length == 2)
                            l_aixIPRouting[l_list[0]]['type'] = 'network'
                        else
                            l_pieces = l_list[0].split('.')
                            if ((l_pieces[-1] == '0') or (l_pieces[-1] == '255'))
                                l_aixIPRouting[l_list[0]]['type'] = 'broadcast'
                            else
                                l_aixIPRouting[l_list[0]]['type'] = 'host'
                            end
                        end
                    end

                end
            end

        end

        #  Implicitly return the contents of the variable
        l_aixIPRouting
    end
end
