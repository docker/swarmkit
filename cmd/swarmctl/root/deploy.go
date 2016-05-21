package root

import (
	"fmt"
	"reflect"

	"github.com/docker/swarm-v2/api"
	"github.com/docker/swarm-v2/cmd/swarmctl/common"
	"github.com/docker/swarm-v2/cmd/swarmctl/network"
	"github.com/spf13/cobra"
)

var (
	deployCmd = &cobra.Command{
		Use:   "deploy",
		Short: "Deploy an app",
		RunE: func(cmd *cobra.Command, args []string) error {
			s, err := readSpec(cmd.Flags())
			if err != nil {
				return err
			}

			c, err := common.Dial(cmd)
			if err != nil {
				return err
			}

			r, err := c.ListServices(common.Context(cmd), &api.ListServicesRequest{})
			if err != nil {
				return err
			}

			services := map[string]*api.Service{}

			for _, j := range r.Services {
				for _, label := range j.Spec.Annotations.Labels {
					if label == "namespace="+s.Namespace {
						services[j.Spec.Annotations.Name] = j
					}
				}
			}

			for _, serviceSpec := range s.ServiceSpecs() {
				if err := network.ResolveServiceNetworks(common.Context(cmd), c, serviceSpec); err != nil {
					return err
				}
				if service, ok := services[serviceSpec.Annotations.Name]; ok && !reflect.DeepEqual(service.Spec, serviceSpec) {
					r, err := c.UpdateService(common.Context(cmd), &api.UpdateServiceRequest{
						ServiceID:      service.ID,
						ServiceVersion: &service.Meta.Version,
						Spec:           serviceSpec,
					})
					if err != nil {
						fmt.Printf("%s: %v\n", serviceSpec.Annotations.Name, err)
						continue
					}
					fmt.Printf("%s: %s - UPDATED\n", serviceSpec.Annotations.Name, r.Service.ID)
					delete(services, serviceSpec.Annotations.Name)
				} else if !ok {
					r, err := c.CreateService(common.Context(cmd), &api.CreateServiceRequest{Spec: serviceSpec})
					if err != nil {
						fmt.Printf("%s: %v\n", serviceSpec.Annotations.Name, err)
						continue
					}
					fmt.Printf("%s: %s - CREATED\n", serviceSpec.Annotations.Name, r.Service.ID)
				} else {
					// nothing to update
					delete(services, serviceSpec.Annotations.Name)
				}
			}

			for _, service := range services {
				_, err := c.RemoveService(common.Context(cmd), &api.RemoveServiceRequest{ServiceID: service.ID})
				if err != nil {

					return err
				}
				fmt.Printf("%s: %s - REMOVED\n", service.Spec.Annotations.Name, service.ID)
			}

			// Process Volumes
			existingVols, err := c.ListVolumes(common.Context(cmd), &api.ListVolumesRequest{})
			if err != nil {
				return err
			}

			volumes := map[string]*api.Volume{}

			for _, j := range existingVols.Volumes {
				for _, label := range j.Spec.Annotations.Labels {
					if label == "namespace="+s.Namespace {
						volumes[j.Spec.Annotations.Name] = j
					}
				}
			}

			for _, volumeSpec := range s.VolumeSpecs() {
				if volume, ok := volumes[volumeSpec.Annotations.Name]; ok && !reflect.DeepEqual(volume.Spec, volumeSpec) {
					fmt.Printf("Update Volume not supported: %s\n", volumeSpec.Annotations.Name)
					delete(volumes, volumeSpec.Annotations.Name)
					continue
					// TODO(amitshukla): should we error out here?
				} else if !ok {
					r, err := c.CreateVolume(common.Context(cmd), &api.CreateVolumeRequest{Spec: volumeSpec})
					if err != nil {
						fmt.Printf("%s: %v\n", volumeSpec.Annotations.Name, err)
						continue
					}
					fmt.Printf("%s: %s - CREATED\n", volumeSpec.Annotations.Name, r.Volume.ID)
				} else {
					// nothing to update
					delete(volumes, volumeSpec.Annotations.Name)
				}
			}

			for _, volume := range volumes {
				_, err := c.RemoveVolume(common.Context(cmd), &api.RemoveVolumeRequest{VolumeID: volume.ID})
				if err != nil {

					return err
				}
				fmt.Printf("%s: %s - REMOVED\n", volume.Spec.Annotations.Name, volume.ID)
			}

			return nil
		},
	}
)

func init() {
	deployCmd.Flags().StringP("file", "f", "docker.yml", "Spec file to deploy")
}
