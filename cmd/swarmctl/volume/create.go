package volume

import (
	"errors"
	"fmt"

	"github.com/docker/swarm-v2/api"
	"github.com/docker/swarm-v2/cmd/swarmctl/common"
	"github.com/spf13/cobra"
)

var (
	createCmd = &cobra.Command{
		Use:   "create",
		Short: "Create a volume",
		RunE: func(cmd *cobra.Command, args []string) error {
			flags := cmd.Flags()
			if !flags.Changed("name") || !flags.Changed("driver") {
				return errors.New("--name and --driver are mandatory")
			}
			name, err := flags.GetString("name")
			if err != nil {
				return err
			}
			driverName, err := flags.GetString("driver")
			if err != nil {
				return err
			}

			opts, err := cmd.Flags().GetStringSlice("opts")
			if err != nil {
				return err
			}

			spec := &api.VolumeSpec{
				Annotations: api.Annotations{
					Name: name,
				},
				DriverConfiguration: &api.Driver{
					Name:    driverName,
					Options: opts,
				},
			}

			c, err := common.Dial(cmd)
			if err != nil {
				return err
			}
			r, err := c.CreateVolume(common.Context(cmd), &api.CreateVolumeRequest{Spec: spec})
			if err != nil {
				return err
			}
			fmt.Println(r.Volume.ID)
			return nil
		},
	}
)

func init() {
	createCmd.Flags().String("name", "", "Volume name")
	createCmd.Flags().String("driver", "", "Volume driver")
	createCmd.Flags().StringSlice("opts", []string{}, "Volume driver options")
}
